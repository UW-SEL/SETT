function r = PropylGlycol(property, C, T)
    % PROPYLGLYCOL Return fluid properties of Propylene Glycol Water brine
    %
    % C -- composition [%]
    % T -- temperature [K]
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
    % Note that pressure is not required for some properties and will be silently ignored if it is provided.
    % pressure is constant at atmospheric pressure for enthlapy becaue 
    % temperature drives the property more than pressure
    %
    % Temperature range is from EES property plots
    % Composition is only for 35 and 40 percent for now
    property = lower(property);
    switch property
        case "dens"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 35
                r = 1041.68389 + 0.418458595*T - 0.00159517445*T^2;
            elseif C == 40
                r = 1069.7675 + 0.296586554*T - 0.00145904297*T^2;
            end
        case "enth"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 35
                r = -933912.227 + 2951.85626*T + 1.42457896*T^2;
            elseif C == 40
                r = -900338.698 + 2785.29373*T + 1.57334021*T^2;
            end
        case "cp"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 35
                r = 2747.79588 + 4.12047598*T - 0.00197478398*T^2;
            elseif C == 40
                r = 2643.24987 + 4.02399541*T - 0.00135137331*T^2;
            end
        case "visc"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 35
                r = 118.32836 - 2.10076282*T + 0.0155176496*T^2 - 0.0000610281586*T^3 + 1.34749766E-07*T^4 - 1.58354463E-10*T^5 + 7.73709124E-14*T^6;
            elseif C == 40
                r = 237.222462 - 4.25616026*T + 0.0317513526*T^2 - 0.000126040757*T^3 + 2.80752556E-07*T^4 - 3.32681986E-10*T^5 + 1.63826357E-13*T^6;
            end
        case "cond"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 35
                r = 0.212608346 + 0.000713628626*T + 5.31880716E-09*T^2;
            elseif C == 40
                r = 0.24042832 + 0.000457688419*T + 3.01892540E-07*T^2;
            end
        otherwise
            error("Unknown property '%s'", property);
    end
end