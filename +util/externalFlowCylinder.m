function [htc] = externalFlowCylinder(u, D, mu, k, rho, Pr)
    % externalFlowCylinder provide the heat transfer associated with flow
    % across a cylinder
    %
    % Necessary inputs are:
    % u: gas approach velocity (m/s)
    % D: diameter of cylinder (m)
    % mu: viscosity (Pa-s)
    % k: conductivity (W/m-K)
    % rho: density (kg/m^3)
    % Pr: Prandtl number (-)
      
    Re = rho * D * u / mu;
    Nusselt = 0.3 + 0.62 * Re^0.5 * Pr^(1/3) * (1 + (Re / 282000)^(5/8))^(4/5) / (1 + (0.4 / Pr)^(2/3))^(1/4);
    htc = Nusselt * k / D;
