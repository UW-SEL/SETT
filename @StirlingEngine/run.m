function run(obj, options)
    % RUN Determine the cyclic steady-state solution for the engine
    %
    % The conditions can be updated before running the engine using optional
    % name-value argument pairs for "T_cold", "T_hot", and "P_0".
    %
    % If the optional name-value argument "ShowResiduals" is true, a figure
    % window is opened and residuals are plotted during the run.
    %
    % The optional "OuterIterationCallback" argument must be a handle to a
    % function that takes the engine object as its only argument.  This
    % function is called after each outer iteration loop.
    arguments
        obj
        options.T_cold = []  % K
        options.T_hot = []   % K
        options.P_0 = []     % Pa
        options.ShowResiduals = false
        options.OuterIterationCallback = []
    end

    % Update engine state with any provided conditions
    if ~isempty(options.T_cold); obj.T_cold = options.T_cold; end
    if ~isempty(options.T_hot); obj.T_hot = options.T_hot; end
    if ~isempty(options.P_0); obj.P_0 = options.P_0; end

    obj.clearSolution()
    solveEngine(obj, options.ShowResiduals, options.OuterIterationCallback)
    calculatePerformance(obj)
    obj.isSolutionAvailable = true;
end


function solveEngine(obj, showResiduals, outerIterCallback)
    obj.numIterations = 0;
    residuals = struct;

    if showResiduals
        fig = figure();
        fig.Name = "Residuals";
        pp = axes();
        semilogy(pp, nan, nan);
        xlabel(pp, "Iteration")
        ylabel(pp, "Relative Error")
        xlim(pp, [0, 10])
        ylim(pp, [1e-6, 0.1])
        lines = [ ...
            animatedline(pp, "Color", [0.000 0.447 0.741]),  ...
            animatedline(pp, "Color", [0.850 0.325 0.098])   ...
        ];
        legend(lines, "T_c", "T_e")
        grid("on")
        title(pp, "Running...")
        drawnow
        timerVal = tic();
    end

    % Run first call updates
    obj.chx.firstCallUpdate(obj)
    obj.regen.firstCallUpdate(obj)
    obj.hhx.firstCallUpdate(obj)
    obj.ws.firstCallUpdate(obj)

    % Set initial approach temperature guesses
    DT_chx = obj.chx.DT;
    DT_regen_cold = obj.regen.DT;
    DT_regen_hot = obj.regen.DT;
    DT_hhx = obj.hhx.DT;

    % Set initial temperatures with best guesses
    T_c_0 = obj.T_cold + DT_chx;
    T_e_0 = obj.T_hot - DT_hhx;

    % Initialize a few useful variables
    solverConfig = obj.config.solver;
    odeSolver = str2func(solverConfig.odeSolver);
    odeOptions = odeset(                          ...
        "AbsTol", solverConfig.odeTolerance.abs,  ...
        "RelTol", solverConfig.odeTolerance.rel   ...
    );
    timeRefinement = 1 / solverConfig.timeResolution;
    innerAbsTol = solverConfig.innerLoopTolerance.abs;
    innerRelTol = solverConfig.innerLoopTolerance.rel;
    outerAbsTol = solverConfig.outerLoopTolerance.abs;
    outerRelTol = solverConfig.outerLoopTolerance.rel;
    hasCallback = isa(outerIterCallback, "function_handle");

    % Outer Iteration Loop
    iterOuter = 0;
    while true
        iterOuter = iterOuter + 1;
        if iterOuter > 50
            error("Did not converge in 50 outer iterations")
        end

        % Set cycle constants
        % Note that the hxr approaches are updated at the end of each outer iteration loop
        obj.freq = obj.ws.freq;
        obj.period = 1 / obj.freq;
        obj.V_k = obj.chx.vol;
        obj.V_r = obj.regen.vol;
        obj.V_l = obj.hhx.vol;
        obj.T_k = obj.T_cold + DT_chx;
        obj.T_l = obj.T_hot - DT_hhx;
        obj.T_r_cold = obj.T_k + DT_regen_cold;
        obj.T_r_hot = obj.T_l - DT_regen_hot;
        obj.T_r = (obj.T_l - 0.5 * DT_regen_hot - obj.T_k - 0.5 * DT_regen_cold) ...
                / log((obj.T_l - 0.5 * DT_regen_hot) / (obj.T_k + 0.5 * DT_regen_cold));

        % Inner Iteration Loop
        iterInner = 0;
        while true
            iterInner = iterInner + 1;
            if iterInner > 100
                error("Did not converge in 100 inner iterations - consider tightening ODE tolerances or relaxing solver tolerances")
            end

            % Solve the ODE
            y0 = [T_c_0; T_e_0; obj.P_0];
            obj.odeSol = odeSolver(@(t, y) odeFunc(obj, t, y), [0, obj.period], y0, odeOptions);

            % Calculate errors
            innerAbsErr = abs(y0(1:2) - obj.odeSol.y(1:2, end));  % [T_c_err, T_e_err]       
            innerRelErr = abs(innerAbsErr ./ y0(1:2));

            % Track residuals
            obj.numIterations = obj.numIterations + 1;
            residuals.absErrors(:, obj.numIterations) = innerAbsErr;
            residuals.relErrors(:, obj.numIterations) = innerRelErr;

            % Plot residuals if requested
            if showResiduals
                % Add these points
                addpoints(lines(1), obj.numIterations, residuals.relErrors(1, end));
                addpoints(lines(2), obj.numIterations, residuals.relErrors(2, end));

                % Keep latest points in view
                ax = lines(1).Parent;
                ymin = ax.YLim(1);
                if any(residuals.relErrors(:, end) < ymin)
                    ax.YLim(1) = ymin / 10;
                end
                ymax = ax.YLim(2);
                if any(residuals.relErrors(:, end) > ymax)
                    ax.YLim(2) = ymax * 10;
                end
                xmax = ax.XLim(2);
                if obj.numIterations > xmax
                    ax.XLim(2) = xmax + 10;
                end

                % Update the plot
                drawnow limitrate
            end

            % Check for convergence
            if iterInner > 1  % force at least two inner iterations
                notConverged = (innerAbsErr > innerAbsTol) .* (innerRelErr > innerRelTol);
                if all(~notConverged)
                    break
                end
            end

            % Update initial temperatures, knowing T_0 = T_final
            T_c_0 = obj.odeSol.y(1, end);
            T_e_0 = obj.odeSol.y(2, end);
        end

        % Inner loop is converged - calculate time-discretized state variables
        numOdeTimesteps = numel(obj.odeSol.x);
        ts = interp1(obj.odeSol.x, 1:timeRefinement:numOdeTimesteps);
        numTimesteps = numel(ts);
        obj.stateValues = struct(                ...
            "time", zeros(1, numTimesteps),      ...
            "T_c", zeros(1, numTimesteps),       ...
            "T_e", zeros(1, numTimesteps),       ...
            "P", zeros(1, numTimesteps),         ...
            "m_dot_ck", zeros(1, numTimesteps),  ...
            "m_dot_kr", zeros(1, numTimesteps),  ...
            "m_dot_rl", zeros(1, numTimesteps),  ...
            "m_dot_le", zeros(1, numTimesteps),  ...
            "Q_dot_k", zeros(1, numTimesteps),   ...
            "Q_dot_r", zeros(1, numTimesteps),   ...
            "Q_dot_l", zeros(1, numTimesteps),   ...
            "dTc_dt", zeros(1, numTimesteps),    ...
            "dTe_dt", zeros(1, numTimesteps),    ...
            "dP_dt", zeros(1, numTimesteps)      ...
        );
        for i = 1:numTimesteps
            t = ts(i);
            y = deval(obj.odeSol, t);
            T_c = y(1);
            T_e = y(2);
            P = y(3);
            values = obj.solveState(T_c, T_e, P, t);
            obj.stateValues.time(i) = t;
            obj.stateValues.T_c(i) = T_c;
            obj.stateValues.T_e(i) = T_e;
            obj.stateValues.P(i) = P;
            obj.stateValues.m_dot_ck(i) = values(1);
            obj.stateValues.m_dot_kr(i) = values(2);
            obj.stateValues.m_dot_rl(i) = values(3);
            obj.stateValues.m_dot_le(i) = values(4);
            obj.stateValues.Q_dot_k(i) = values(5);
            obj.stateValues.Q_dot_r(i) = values(6);
            obj.stateValues.Q_dot_l(i) = values(7);
            obj.stateValues.dTc_dt(i) = values(8);
            obj.stateValues.dTe_dt(i) = values(9);
            obj.stateValues.dP_dt(i) = values(10);

        end

        % Calculate and store average pressure
        obj.P_ave = trapz(obj.stateValues.time, obj.stateValues.P) * obj.freq;

        % Run callback function if provided
        if hasCallback
            outerIterCallback(obj);
        end

        % Check if component models are converged
        approaches = [DT_chx; DT_regen_cold; DT_regen_hot; DT_hhx];
        if iterOuter > 1  % force at least two outer iterations
            outerAbsErr = abs(approaches - prevApproaches);
            outerRelErr = abs(outerAbsErr ./ prevApproaches);
            notConverged = (outerAbsErr > outerAbsTol) .* (outerRelErr > outerRelTol);
            if all(~notConverged)
                % Heat exchangers are converged - check working spaces model
                if obj.ws.isConverged
                    break
                end
            end
        end
        prevApproaches = approaches;

        % Update the dependent ΔT of the regenerator
        DT_regen_hot = solveRegen(obj, DT_regen_hot);
        DT_regen_offset = DT_regen_hot - DT_regen_cold;

        % Update component models
        obj.chx.update(obj)
        obj.regen.update(obj)
        obj.hhx.update(obj)
        obj.ws.update(obj)

        % Averaging the approaches with the previous iteration improves convergence
        DT_chx = 0.5 * (DT_chx + obj.chx.DT);
        DT_regen_cold = 0.5 * (DT_regen_cold + obj.regen.DT);
        DT_regen_hot = DT_regen_cold + DT_regen_offset;
        DT_hhx = 0.5 * (DT_hhx + obj.hhx.DT);

        % Using calculated approach for early iterations speeds convergence
        if iterOuter < 5
            DT_chx = obj.chx.DT;
            DT_regen_cold = obj.regen.DT;
            DT_regen_hot = DT_regen_cold + DT_regen_offset;
            DT_hhx = obj.hhx.DT;
        end
    end

    % Save residuals arrays
    obj.residuals = residuals;

    % Run last call updates
    obj.chx.lastCallUpdate(obj)
    obj.regen.lastCallUpdate(obj)
    obj.hhx.lastCallUpdate(obj)
    obj.ws.lastCallUpdate(obj)

    if showResiduals
        elapsed = toc(timerVal);
        title(pp, sprintf("Run Finished (%.1f sec)", elapsed))
    end
end



function dydt = odeFunc(obj, t, y)
    % ODEFUNC Return the derivatives of T_c, T_e, and P at a given time
    T_c = y(1);
    T_e = y(2);
    P = y(3);
    x = obj.solveState(T_c, T_e, P, t);
    dydt = [
        x(8);  % dTc_dt
        x(9);  % dTe_dt
        x(10); % dP_dt
    ];
end



function DT_regen_hot = solveRegen(obj, DT_regen_hot)
    % SOLVEREGEN Determine the dependent regenerator approach temperature
    %
    % The regen component is responsible for providing only the min ΔT of the regenerator, so the
    % other approach must be iteratively updated each outer loop knowing the heat flow in to and
    % out of the regenerator over a cycle must sum to zero.
    %
    % TODO: For now we assume min ΔT is on the cold side...
    %       In the future we could check this on each iteration and swap if needed,
    %       or we could say that the DT of the regen component must always be cold side

    % Calculate total energy flow to and from the chx
    neg_flow_cold = obj.stateValues.m_dot_kr < 0;  % negative m_dot is flow out to chx
    pos_flow_cold = ~neg_flow_cold;
    h_cold = zeros(1, numel(obj.stateValues.P));
    h_cold(pos_flow_cold) = obj.fluid.enthalpy(obj.T_k, obj.stateValues.P(pos_flow_cold));       % enthalpy entering regen
    h_cold(neg_flow_cold) = obj.fluid.enthalpy(obj.T_r_cold, obj.stateValues.P(neg_flow_cold));  % enthalpy leaving regen
    Q_dot_cold = obj.stateValues.m_dot_kr .* h_cold;
    Q_cold = trapz(obj.stateValues.time, Q_dot_cold);

    % Calculate total energy flow to and from the hhx
    neg_flow_hot = obj.stateValues.m_dot_rl < 0;  % negative m_dot is flow in from hhx
    pos_flow_hot = ~neg_flow_hot;
    h_hot = zeros(1, numel(obj.stateValues.P));
    h_hot(pos_flow_hot) = obj.fluid.enthalpy(obj.T_r_hot, obj.stateValues.P(pos_flow_hot));  % enthalpy leaving regen
    h_hot(neg_flow_hot) = obj.fluid.enthalpy(obj.T_l, obj.stateValues.P(neg_flow_hot));      % enthalpy entering regen
    Q_dot_hot = obj.stateValues.m_dot_rl .* h_hot;
    Q_hot = trapz(obj.stateValues.time, Q_dot_hot);

    adjustment = (Q_cold - Q_hot) / Q_hot;  % TODO: compare stability and speed with different normalizing values
    DT_regen_hot = DT_regen_hot * (1 + adjustment);
end



function calculatePerformance(obj)
    % CALCULATEPERFORMANCE Add performance metrics to engine object

    % Calculate indicated power with and without pressure drops
    [~, dVc_dt, ~, dVe_dt] = obj.ws.values(obj.stateValues.time);
    DP = obj.chx.DP + obj.regen.DP + obj.hhx.DP;
    P_c = obj.stateValues.P + 0.5 * DP;  % m_dot from cold to hot is positive
    P_e = obj.stateValues.P - 0.5 * DP;
    obj.indicatedPower = obj.freq * trapz(  ...
        obj.stateValues.time,               ...
        P_c .* dVc_dt + P_e .* dVe_dt       ...
    );
    obj.indicatedPowerZeroDP = obj.freq * trapz(  ...
        obj.stateValues.time,                     ...
        obj.stateValues.P .* (dVc_dt + dVe_dt)    ...
    );

    % Calculate shaft power (indicated power less ws mechanical parasitics) and torque
    obj.shaftPower = obj.indicatedPower - obj.ws.W_parasitic_c - obj.ws.W_parasitic_e;
    obj.shaftTorque = obj.shaftPower / (2 * pi * obj.freq);

    % Calculate net power (shaft power less hxr mechanical parasitics)
    obj.netPower = obj.shaftPower - obj.chx.W_parasitic - obj.hhx.W_parasitic;

    % Calculate heat input
    Q_dot_e = obj.freq * trapz(                       ...
        obj.stateValues.time,                         ...
        (obj.stateValues.T_e - obj.T_l) / obj.ws.R_e  ...
    );
    Q_dot_l = obj.freq * trapz(  ...
        obj.stateValues.time,    ...
        obj.stateValues.Q_dot_l  ...
    );
    Q_dot_loss_external = obj.hhx.Q_parasitic + obj.regen.Q_parasitic + obj.ws.Q_parasitic_e;
    obj.heatInput = Q_dot_l - Q_dot_e + Q_dot_loss_external;  % negative Q_dot_e is heat into expansion space

    % Calculate heat rejection
    Q_dot_c = obj.freq * trapz(                       ...
        obj.stateValues.time,                         ...
        (obj.stateValues.T_c - obj.T_k) / obj.ws.R_c  ...
    );
    Q_dot_k = obj.freq * trapz(  ...
        obj.stateValues.time,    ...
        obj.stateValues.Q_dot_k  ...
    );
    Q_dot_DP = obj.indicatedPowerZeroDP - obj.indicatedPower;  % heat from pressure drops that must be rejected
    Q_dot_loss_internal = obj.ws.W_parasitic_c + obj.ws.W_parasitic_e;  % heat from internal parasitic losses
    obj.heatRejection = Q_dot_c + Q_dot_k + Q_dot_DP + Q_dot_loss_internal + Q_dot_loss_external;

    % Calculate net efficiency
    obj.efficiency = obj.netPower / obj.heatInput;
end
