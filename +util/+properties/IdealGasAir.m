function r = IdealGasAir(property, T, P)
    % IDEALGASAIR Return fluid properties of ideal gas air
    %
    % T -- temperature [K]
    % P -- pressure [Pa]
    %
    % The returned property is specified with the string argument 'property',
    % which is case-insensitive and must be one of:
    %   dens -- density [kg/m3]
    %   enth -- specific enthapy [J/kg-K] (P is not required for this property)
    %   cp   -- specific heat at constant pressure [J/kg-K] (P is not required for this property)
    %   visc -- viscosity [Pa-s]
    %   cond -- thermal conductivity [W/m-K]
    % TODO: Add other properties as needed
    %
    % Enthalpy and CP are based on curve fits between 250 K and 1800 K.  Note that pressure
    % is not required for some properties and will be silently ignored if it is provided.
    %
    % Example usage within a component:
    %   h = util.properties.IdealGasAir("enth", 400);  % enthalpy of ideal gas air at 400 K
    %   rho = util.properties.IdealGasAir("dens", 450, 101300);  % density of air at 450 K and 101.3 kPa
    property = lower(property);
    switch property
        case "dens"
            R = 287;  % J/kg-K
            r = P ./ (R * T);
        case "enth"
            if T < 250 || T > 1800
                warning("Temperature outside range of curve fit")
            end
            r = 4211.41888 + 954.63*T + 0.0881337818*T^2;
        case "cp"
            if T < 250 || T > 1800
                warning("Temperature outside range of curve fit")
            end
            r = 1035.246 - 0.321392509*T + 0.000886350586*T^2 - 5.86200926E-07*T^3 + 1.26672705E-10*T^4;
        case "visc"
            if T < 250 || T> 1800
                warning("Temperature outside range of curve fit")
            end
            r = 0.00000700468306 + 4.29358191E-08*T - 8.09117803E-12*T^2;
        case "cond"
            if T < 250 || T > 1800
                warning("Temperature outside range of curve fit")
            end
            r = 0.00426795536 + 0.0000775038829*T - 1.47534876E-08*T^2;
        otherwise
            error("Unknown property '%s'", property);
    end
end
