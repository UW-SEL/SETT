function report(obj)
    % REPORT Display a detailed engine report

    if ~obj.isSolutionAvailable
        error("Engine must be run first")
    end

    printWithHeader("Conditions", [
        sprintf("   Speed = %g rpm", obj.freq * 60),
        sprintf(""),
        sprintf("     P_0 = %g Pa", obj.P_0),
        sprintf("   P_ave = %.4g Pa", obj.P_ave),
        sprintf(""),
        sprintf("  T_cold = %.1f K", obj.T_cold),
        sprintf("     T_k = %.1f K", obj.T_k),
        sprintf("T_r_cold = %.1f K", obj.T_r_cold),
        sprintf("     T_r = %.1f K", obj.T_r),
        sprintf(" T_r_hot = %.1f K", obj.T_r_hot),
        sprintf("     T_l = %.1f K", obj.T_l),
        sprintf("   T_hot = %.1f K", obj.T_hot),
    ])

    printWithHeader("Energy", [
        sprintf("      Net Efficiency = %.2f %%", obj.efficiency * 100),
        sprintf(""),
        sprintf("           Net Power = %g W", obj.netPower),
        sprintf("         Shaft Power = %g W", obj.shaftPower),
        sprintf("          Ind. Power = %g W", obj.indicatedPower),
        sprintf("Ind. Power (Zero ΔP) = %g W", obj.indicatedPowerZeroDP),
        sprintf(""),
        sprintf("          Heat Input = %g W", obj.heatInput),
        sprintf("      Heat Rejection = %g W", obj.heatRejection),
        sprintf(""),
        sprintf("      Rel. Imbalance = %.3e %%", 100 * (obj.heatInput - obj.heatRejection - obj.shaftPower) / obj.heatInput),
    ])

    % Calculate mass at each timestep
    [V_c, ~, V_e, ~] = obj.ws.values(obj.stateValues.time);
    rho_c = obj.fluid.density(obj.stateValues.T_c, obj.stateValues.P);
    rho_k = obj.fluid.density(obj.T_k, obj.stateValues.P);
    rho_r = obj.fluid.density(obj.T_r, obj.stateValues.P);
    rho_l = obj.fluid.density(obj.T_l, obj.stateValues.P);
    rho_e = obj.fluid.density(obj.stateValues.T_e, obj.stateValues.P);
    mass_c = V_c .* rho_c;
    mass_k = obj.chx.vol .* rho_k;
    mass_r = obj.regen.vol .* rho_r;
    mass_l = obj.hhx.vol .* rho_l;
    mass_e = V_e .* rho_e;
    mass_total = mass_c + mass_k + mass_r + mass_l + mass_e;

    totalMass = obj.freq * trapz(  ...
        obj.stateValues.time,      ...
        mass_total                 ...
    );
    m_dot_ave = struct(                                                       ...
        "chx", obj.freq * trapz(                                              ...
            obj.stateValues.time,                                             ...
            abs(0.5 * (obj.stateValues.m_dot_ck + obj.stateValues.m_dot_kr))  ...
        ),                                                                    ...
        "regen", obj.freq * trapz(                                            ...
            obj.stateValues.time,                                             ...
            abs(0.5 * (obj.stateValues.m_dot_kr + obj.stateValues.m_dot_rl))  ...
        ),                                                                    ...
        "hhx", obj.freq * trapz(                                              ...
            obj.stateValues.time,                                             ...
            abs(0.5 * (obj.stateValues.m_dot_rl + obj.stateValues.m_dot_le))  ...
        )                                                                     ...
    );
    fluidCompParts = split(metaclass(obj.fluid).Name, ".");
    switch fluidCompParts{3}
        case "PerfectGas"
            header = sprintf("Working Fluid - %s (Perfect Gas)", obj.config.fluid.params.name);
        case "IdealGas"
            header = sprintf("Working Fluid - %s (Ideal Gas)", obj.config.fluid.params.name);
        case "RealGasRefprop"
            header = sprintf("Working Fluid - %s (REFPROP)", obj.config.fluid.params.name);
        otherwise
            header = sprintf("Working Fluid - %s", fluidCompParts{3});
    end
    printWithHeader(header, [
        sprintf("            Total Mass = %.3e kg", totalMass),
        sprintf("   Rel. Mass Imbalance = %.3e %%", 100 * (max(mass_total) - min(mass_total)) / totalMass),
        sprintf(""),
        sprintf("Ave. Flow Rate (chx)   = %.3e kg/s", m_dot_ave.chx),
        sprintf("Ave. Flow Rate (regen) = %.3e kg/s", m_dot_ave.regen),
        sprintf("Ave. Flow Rate (hhx)   = %.3e kg/s", m_dot_ave.hhx),
    ])

    writeComponentReport(obj.ws)
    writeComponentReport(obj.chx)
    writeComponentReport(obj.regen)
    writeComponentReport(obj.hhx)
end


function writeComponentReport(comp)
    compName =  metaclass(comp).Name;
    parts = split(compName, ".");
    header = sprintf("%s - %s", parts{2}, parts{3});
    switch parts{2}
        case "ws"
            lines = [];
        case "chx"
            lines = [
                sprintf("     Volume = %.3e m^3", comp.vol),
                sprintf("   Approach = %.3e K", comp.DT),
                sprintf("      R_hyd = %.3e Pa-s/m^3", comp.R_hyd),
                sprintf("W_parasitic = %.3e W", comp.W_parasitic),
            ];
        case "regen"
            lines = [
                sprintf("     Volume = %.3e m^3", comp.vol),
                sprintf("   Approach = %.3e K", comp.DT),
                sprintf("      R_hyd = %.3e Pa-s/m^3", comp.R_hyd),
                sprintf("Q_parasitic = %.3e W", comp.Q_parasitic),
            ];
        case "hhx"
            lines = [
                sprintf("     Volume = %.3e m^3", comp.vol),
                sprintf("   Approach = %.3e K", comp.DT),
                sprintf("      R_hyd = %.3e Pa-s/m^3", comp.R_hyd),
                sprintf("W_parasitic = %.3e W", comp.W_parasitic),
                sprintf("Q_parasitic = %.3e W", comp.Q_parasitic),
            ];
        otherwise
            lines = [];
    end
    if ismethod(comp, "report")
        footerLines = comp.report();
    else
        footerLines = [];
    end
    printWithHeader(header, lines, footerLines)
end



function printWithHeader(header, lines, footerLines)
    % PRINTWITHHEADER Nicely format lines with a header and footer

    % Determine longest string
    longest = strlength(header);
    for index = 1:length(lines)
        longest = max(longest, length(lines{index}));
    end
    if nargin > 2
        for index = 1:length(footerLines)
            longest = max(longest, length(footerLines{index}));
        end
    end
    longest = longest + 2;

    % Print the header
    fprintf("\n")
    fprintf("%s", repmat("=", [1, longest]));
    fprintf("\n<strong>%*s</strong>\n", (longest + strlength(header)) / 2, header);
    if length(lines) > 0
        fprintf("%s", repmat("-", [1, longest]));
        fprintf("\n")
    end

    % Print the lines
    for index = 1:length(lines)
        fprintf(" %s\n", lines{index});
    end

    % Print the footer
    if nargin > 2
        if length(footerLines) > 0
            fprintf("%s", repmat("-", [1, longest]));
            fprintf("\n")
        end
        for index = 1:length(footerLines)
            fprintf(" %s\n", footerLines{index});
        end
    end

    % Print the footer
    fprintf("%s", repmat("=", [1, longest]));
    fprintf("\n")
end
