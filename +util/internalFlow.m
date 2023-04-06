function [f, Nu] = internalFlow(Re, Pr, L_tube, D_h, roughness)
    % INTERNALFLOW Provide the friction factor and Nusselt number for internal steady developing flow through a tube
    %
    % Necessary inputs are:
    % Re: Reynolds number [dimensionless] 
    % Pr: Prandtl number [dimensionless] 
    % L_tube: Length of tube [m] 
    % D_h: hydraulic diameter of tube [m] 
    % roughness [m]

    % get Nusselt number and friction factor from correlations
    if Re < 2300
        % laminar flow
        L_hat = L_tube / (D_h * Re);
        f = 64 / Re;
        f = f * (0.215 * L_hat^(-0.5) + (0.0196 / L_hat + 1 - 0.215 * L_hat^(-0.5)) / (1 + 0.00021 * L_hat^(-2)));
        Gz = D_h * Re * Pr / L_tube;
        Nu = 3.66 + (0.049 + 0.020 / Pr) * Gz^1.12 / (1 + 0.065 * Gz^0.7);

    elseif Re < 4000
        % transitional flow
        L_hat = L_tube / (D_h * 2300);
        f_low = 64 / 2300;
        f_low = f_low * (0.215 * L_hat^(-0.5) + (0.0196 / L_hat + 1 - 0.215 * L_hat^(-0.5)) / (1 + 0.00021 * L_hat^(-2)));
        Gz = D_h * 2300 * Pr / L_tube;
        Nusselt_low = 3.66 + (0.049 + 0.020 / Pr) * Gz^1.12 / (1 + 0.065 * Gz^0.7);

        f_high = 4 * (-0.0015702 / log(4000) + 0.3942031 / (log(4000))^2 + 2.5341533 / (log(4000))^3);
        Nusselt_high = (f_high / 8) * (4000-1000) * Pr / (1 + 12.7 * (Pr^(2/3) - 1) * sqrt(f_high / 8));

        Nu = Nusselt_low + (Re - 2300) / (4000 - 2300) * (Nusselt_high - Nusselt_low);
        f = f_low + (Re - 2300) / (4000 - 2300) * (f_high - f_low);

    else
        % turbulent flow
        if roughness == 0
            % smooth turbulent flow
            f = 4 * (-0.0015702 / log(Re) + 0.3942031 / (log(Re))^2 + 2.5341533 / (log(Re))^3);
            if Re > 5e6
                warning("water side Reynolds number in whx model NASAModII is > 5e6");
            end
        else
            % turbulent flow in rough pipe
            rel_roughness = roughness/D_h;
            % friction factor correlation from Offor and Alabi 2016
            f = (-2 * log10((roughness / (3.71 * D_h)) + ((-1.975 / Re) * (log( (rel_roughness/3.93)^(1.092) + (7.627 / (395.9 + Re)) )))))^(-2);
            if rel_roughness < 1e-6
                warning("relative roughness in water side in whx model NASAModII is < 1e-6");
            elseif rel_roughness > 5e-2
                warning("relative roughness in water side in whx model NASAModII is > 5e-2");
            end
        end
        
        Nu = (f / 8) * (Re - 1000) * Pr / (1 + 12.7 * (Pr^(2/3) - 1) * sqrt(f / 8));
        Nu = Nu * (1 + (L_tube / D_h)^(-0.7));
    end
end
