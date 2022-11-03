function [DP_g, h] = tubeFlow(fluid_properties, m_dot, D, L, roughness, ft)

    % tubeFlow Provide the pressure drop and heat transfer for flow through
    % a round tube assuming steady state - use the function oscillatingFlow
    % to get multipliers to apply to this result
    %
    % Necessary inputs are:
    % fluid_properties [call function]
    % m_dot, mass flow rate [kg/s]
    % D, inner diameter (m)
    % L, length of tube (m)
    % roughness, tube wall roughness (m)
    % ft, optional parameter - set to 1 to force turbulent result
    
    %properties 
    cp_g = fluid_properties.CP;
    rho_g = fluid_properties.rho;
    mu_g = fluid_properties.mu;
    k_g = fluid_properties.k;
    Pr_g = mu_g * cp_g / k_g;
    A_c = pi*D^2/4;                     %Cross sectional area
    u_g = m_dot/(rho_g*A_c);          %velocity
    Re_g = u_g*D*rho_g/mu_g;
    if exist('ft','var')
        Re_g = Re_g + 5000;  %add 5000 to force it into turbulent logic - subtract 5000 there
    end
    if Re_g < 2300
         %laminar flow
         L_hat = L / (D * Re_g);        %dimensionless length
         f_g = 64 / Re_g;               %fully developed friction factor
         %adjust friction factor for developing flow
         f_g = f_g * (0.215 * L_hat^(-0.5) + (0.0196 / L_hat + 1 - 0.215 * L_hat^(-0.5)) / (1 + 0.00021 * L_hat^(-2)));
         Gz = D * Re_g * Pr_g / L;  %Graetz number
         Nusselt_g = 3.66 + (0.049 + 0.020 / Pr_g) * Gz^1.12 / (1 + 0.065 * Gz^0.7);  %Nusselt number adjusted for developing flow
    elseif Re_g < 4000
         %transitional flow
         %first get f_g and Nusselt_g at Re_g = 2300, f_g_low and Nusselt_g_low
         L_hat = L / (D * 2300);
         f_g_low = 64 / 2300;  
         f_g_low = f_g_low * (0.215 * L_hat^(-0.5) + (0.0196 / L_hat + 1 - 0.215 * L_hat^(-0.5)) / (1 + 0.00021 * L_hat^(-2)));

         Gz = D * 2300 * Pr_g / L;
         Nusselt_g_low = 3.66 + (0.049 + 0.20 / Pr_g) * Gz^1.12 / (1 + 0.065 * Gz^0.7);

         %then get f_g and Nusselt_g at Re_g = 4000, f_g_high and Nusselt_g_high
         f_g_high = 4 * (-0.0015702 / log(4000) + 0.3942031 / (log(4000))^2 + 2.5341533 / (log(4000))^3);
         Nusselt_g_high = (f_g_high / 8) * (4000-1000) * Pr_g / (1 + 12.7 * (Pr_g^(2/3) - 1) * sqrt(f_g_high / 8));

         %finally interpolate between these values to get a smooth
         %transition from laminar to turbulent
         Nusselt_g = Nusselt_g_low + (Re_g - 2300) / (4000 - 2300) * (Nusselt_g_high - Nusselt_g_low);
         f_g = f_g_low + (Re_g - 2300) / (4000 - 2300) * (f_g_high - f_g_low);
    else
         if exist('ft','var')
             Re_g = Re_g - 5000;  %subtract 5000 to get actual Re
         end
         %turbulent flow
         if roughness == 0
              %smooth turbulent flow
              f_g = 4 * (-0.0015702 / log(Re_g) + 0.3942031 / (log(Re_g))^2 + 2.5341533 / (log(Re_g))^3);
              if Re_g > 5e6
                   warning("Reynolds number in tubeFlow is > 5e6");
              end
         else
              %turbulent flow in rough pipe
              rel_roughness = roughness/D;
              %friction factor correlation from Offor and Alabi (2016)
              f_g = (-2 * log10((roughness / (3.71 * D)) + ((-1.975 / Re_g) * (log((rel_roughness/3.93)^(1.092) + (7.627 / (395.9 + Re_g)) )))))^(-2);
              if rel_roughness < 1e-6
                   warning("relative roughness in tubeFlow is < 1e-6")
              elseif rel_roughness > 5e-2
                   warning("relative roughness in tubeFlow is > 0.05")
              end
         end
         %Nusselt number fully developed
         Nusselt_g = (f_g / 8) * (Re_g - 1000) * Pr_g / (1 + 12.7 * (Pr_g^(2/3) - 1) * sqrt(f_g / 8));
         Nusselt_g = Nusselt_g * (1 + (L / D)^(-0.7));  %correct for developing flow
         f_g = f_g*(1+(L / D)^(-0.7)); %correct for developing flow
    end
     h = Nusselt_g * k_g / D;  %heat transfer coefficient
     DP_g = rho_g * u_g^2 / 2 * (f_g * L / D);
    
