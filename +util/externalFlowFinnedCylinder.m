function [htc] = externalFlowFinnedCylinder(u, D, mu, k, rho, Pr)
    % externalFlowFinnedCylinder provides the heat transfer associated with flow
    % across a finned cylinder using the data presented in:
    % Automotive Stirling Engine Development Program, Jan 1 - June 30, 1985
    %
    % Necessary inputs are:
    % u: gas approach velocity (m/s)
    % D: diameter of cylinder (m)
    % mu: viscosity (Pa-s)
    % k: conductivity (W/m-K)
    % rho: density (kg/m^3)
    % Pr: Prandtl number (-)
      
    Re = rho * D * u / mu;
    log10Re = log10(Re);
    log10Nu=-0.441732471 + 0.582114886*log10Re;
    Nusselt = 10^log10Nu;
    htc = Nusselt * k / D;
