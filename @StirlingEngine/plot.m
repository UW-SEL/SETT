function plot(obj, plotType, varargin)
    % PLOT Show various engine plots
    %
    % The plot type can be one of:
    %   ode-solution
    %   pv-diagram
    %   mass-flow
    %   temperature
    %   residuals
    %   performance-map

    % Define and parse the function arguments
    p = inputParser;
    addRequired(p, "plotType");
    addParameter(p, "figNumber", 0, @(x) isscalar(x) && (x > 0));
    addParameter(p, "figTitle", plotType);
    addParameter(p, "plotTitle", "");
    addParameter(p, "showGrid", true, @(x) islogical(x));
    addParameter(p, "showIdealPressure", false, @(x) islogical(x));
    addParameter(p, "uiAxes", false)
    parse(p, plotType, varargin{:});

    if p.Results.uiAxes ~= false
        ax = p.Results.uiAxes;
    else
        % Create the figure and give it a name
        if p.Results.figNumber == 0
            fig = figure();
        else
            fig = figure(p.Results.figNumber);
        end
        fig.Name = p.Results.figTitle;
        ax = gca;
    end

    switch plotType
       case "ode-solution"
            plotOdeSolution(obj, ax)
        case "pv-diagram"
            plotPV(obj, ax, p.Results.showIdealPressure)
        case "mass-flow"
            plotMassFlow(obj)
        case "temperature"
            plotTemperature(obj)
        case "residuals"
            plotResiduals(obj, ax)
        case "performance-map"
            plotPerformanceMap(obj)
       otherwise
            error("Unknown plot name: %s", name)
    end

    if p.Results.showGrid
        grid(ax, "on")
    end
    title(ax, p.Results.plotTitle)
end


function plotOdeSolution(obj, ax)
    % Extract the values to plot
    x = obj.odeSol.x;
    T_c = obj.odeSol.y(1, :);
    T_e = obj.odeSol.y(2, :);
    P = obj.odeSol.y(3, :);

    % Plot values
    yyaxis(ax, "left")
    plot(ax, x, T_c, "b-o")
    hold(ax, "on")
    plot(ax, x, T_e, "r-o")
    hold(ax, "off")
    ylabel(ax, "Temperature (K)")
    yyaxis(ax, "right")
    plot(ax, x, P, "ko-")
    ylabel(ax, "Pressure (Pa)")
    xlabel(ax, "Time (s)")

    % Adjust axes color
    ax.YAxis(1).Color = "k";
    ax.YAxis(2).Color = "k";
end


function plotPV(obj, ax, showIdealPressure)
    [V_c, ~, V_e, ~] = obj.ws.values(obj.stateValues.time);
    DP = obj.chx.DP + obj.regen.DP + obj.hhx.DP;
    P_c = obj.stateValues.P + 0.5 * DP;  % m_dot from cold to hot is positive
    P_e = obj.stateValues.P - 0.5 * DP;
    plot(ax, V_c, P_c, "b")
    hold(ax, "on")
    plot(ax, V_e, P_e, "r")
    if showIdealPressure
        P = obj.stateValues.P;
        plot(ax, V_c, P, "b--", V_e, P, "r--")
    end
    hold(ax, "off")
    xlabel(ax, "Volume (m^{3})")
    ylabel(ax, "Pressure (Pa)")
    legend(ax, "Compression Space", "Expansion Space")
end


function plotMassFlow(obj)
    t = obj.stateValues.time;
    plot(t, obj.stateValues.m_dot_ck, "b", "DisplayName", "m_{dot,ck}")
    hold on
    plot(t, obj.stateValues.m_dot_kr, "r", "DisplayName", "m_{dot,kr}")
    plot(t, obj.stateValues.m_dot_rl, "k", "DisplayName", "m_{dot,rl}")
    plot(t, obj.stateValues.m_dot_le, "g", "DisplayName", "m_{dot,le}")
    hold off
    xlabel("Time (s)")
    ylabel("Mass flow rate (kg/s)")
    legend()
end


function plotTemperature(obj)
    t = obj.stateValues.time;
    t_endpoints = [t(1), t(end)];
    plot(t_endpoints, [obj.T_hot, obj.T_hot], "DisplayName", "T_{hot}")
    hold on
    plot(t, obj.stateValues.T_e, "DisplayName", "T_e")
    plot(t_endpoints, [obj.T_l, obj.T_l], "DisplayName", "T_l")
    plot(t_endpoints, [obj.T_r_hot, obj.T_r_hot], "DisplayName", "T_{r,hot}")
    plot(t_endpoints, [obj.T_r, obj.T_r], "DisplayName", "T_r")
    plot(t_endpoints, [obj.T_r_cold, obj.T_r_cold], "DisplayName", "T_{r,cold}")
    plot(t_endpoints, [obj.T_k, obj.T_k], "DisplayName", "T_k")
    plot(t, obj.stateValues.T_c, "DisplayName", "T_c")
    plot(t_endpoints, [obj.T_cold, obj.T_cold], "DisplayName", "T_{cold}")
    hold off
    legend()
    xlabel("Time (s)")
    ylabel("Temperature (K)")
end


function plotResiduals(obj, ax)
    iters = 1:size(obj.residuals.relErrors, 2);
    semilogy(ax, iters, obj.residuals.relErrors)
    xlabel(ax, "Iteration")
    ylabel(ax, "Relative Error")
    legend(ax, "T_c", "T_e")
end


function plotPerformanceMap(obj)

    % Hide figure when running engine
    fig = gcf();
    fig.Visible = false;

    % TODO: These need to be provided as function arguments
    speedLow = 500;
    speedHigh = 4500;
    presLow = 1e6;
    presHigh = 12e6;
    numSpeed = 10;
    numPres = 10;

    N_vec = linspace(speedLow, speedHigh, numSpeed);
    P_vec = linspace(presLow, presHigh, numPres);
    [speed, P] = meshgrid(N_vec, P_vec);

    efficiency = NaN(size(speed));
    power = NaN(size(speed));

    f = waitbar(                              ...
        0,                                    ...
        "",                                   ...
        "Name","Generating Performance Map",  ...
        "CreateCancelBtn",                    ...
        "setappdata(gcbf,'canceling',1)"      ...
    );
    setappdata(f,"canceling",0);

    totalRuns = numel(speed);
    for i = 1:totalRuns
        if getappdata(f,"canceling")  % cancel button was clicked
            break
        end

        obj.updateParams("ws.frequency", speed(i) / 60)
        obj.run("P_0", P(i))
        if obj.P_ave > 15e6
            continue
        end
        if obj.P_ave < 2e6
            continue
        end
        efficiency(i) = obj.efficiency;
        power(i) = obj.netPower;

        waitbar(i/totalRuns,f,sprintf("Run %i of %i", i, totalRuns))
    end
    delete(f)

    [C,h] = contourf(speed, power, efficiency * 100);
    clabel(C, h)
    xlabel("Speed (rpm)")
    ylabel("Net Power (W)")
    title("Efficiency (%)")
    fig.Visible = true;
end
