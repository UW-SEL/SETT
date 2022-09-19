function [DP_g, h] = wovenMeshFlow(fluid_properties, mass_flux, correlationj, correlationf, phi, r_h, A_s, A_f, sigma_mesh)
    % wovenMeshFlow Provide the pressure drop and heat transfer for flow through a woven mesh
    %
    % Necessary inputs are:
    %fluid properties[call function]
    %mass flux [kg/m^2 s]
    %correlationj ["Kays and London", or "Gedeon and Wood"]
    %correlationf ["Kays and London", or "Gedeon and Wood"]
    %phi, porosity of matrix [-]
    %r_h, hydraulic radius [m] 
    %A_s, surface area of the regenerator [m^2]
    %A_f, frontal area of the regenerator [m^2]
    %sigma_mesh, [-] ratio of open to frontal area
    
    %properties 
    cp_g = fluid_properties.CP; 
    rho_g = fluid_properties.rho;
    mu_g = fluid_properties.mu;
    k_g = fluid_properties.k;
    Pr_g = mu_g * cp_g / k_g;
    Re = 4 * mass_flux * r_h / mu_g;        %Reynolds number defined as discussed in Kays and London
    switch correlationj
        case "Kays and London"
            logRe = log10(Re);
            logj = -0.37733472-0.3497802 * logRe + 0.017846705 * logRe^2 ...
                -0.74185288 * phi + 1.7508701 * phi^2 - 0.24020448 * logRe * phi;
            j_H = 10^logj;
            h = j_H * G * cp_g / Pr_g^(2/3);
        case "Gedeon and Wood"
            Pe = Re * Pr_g;
            Nusselt = (1 + 0.64 * Pe^0.72) * phi^1.79;
            h = Nusselt * k_g / (4 * r_h);
        otherwise
            error("correlationj in wovenMeshFlow function is unrecognized");
    end

    %use correct correlation for f
    switch correlationf
        case "Kays and London"
            logRe = log10(Re);
            logf = 39.795746 - 141.68695 * phi + 170.11137 * phi^2 - 64.582164 * phi^3 ...
                -6.7368216 * logRe + 1.0453129 * logRe^2 - 0.034984258 * logRe^3 + 15.544004 * phi * logRe ...
                -2.011753 * phi * logRe^2 - 11.807555 * phi^2 * logRe + 1.557376 * phi^2 * logRe^2;
            f = 10^logf;
        case "Gedeon and Wood"
            f = (129 / Re + 2.91 * Re^(-0.103)) / 4; %note factor of 4 is to go from Darcy to Fanning friction factor
        otherwise
            error("correlationj in wovenMeshFlow function is unrecognized");
    end

    DP_g = mass_flux^2 * f * A_s / (2 * A_f * sigma_mesh * rho_g);
