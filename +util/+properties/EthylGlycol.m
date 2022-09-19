function r = EthylGlycol(property, C, T)
    % ETHYLGLYCOL Return fluid properties of Ethylene Glycol Water brine
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
    % Composition is only for 30 and 35 percent for now
    property = lower(property);
    switch property
        case "dens"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 30
                r = 951.326194 + 0.998555271*T - 0.00240080797*T^2;
            elseif C == 35
                r = 986.967299 + 0.838045345*T - 0.002187472*T^2;
            end
        case "enth"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 30
                r = -935263.147 + 2950.05179*T + 1.31210824*T^2;
            elseif C == 35
                r = -892307.833 + 2721.3353*T + 1.53574948*T^2;
            end
        case "cp"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 30
                r = 2398.98704 + 6.06113253*T - 0.00531351789*T^2;
            elseif C == 35
                r = 1969.53808 + 7.75755532*T - 0.00724065976*T^2;
            end
        case "visc"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 30
                r = 5.34931493 - 0.0772097703*T + 0.000446072746*T^2 - 0.00000128836089*T^3 + 1.85919305E-09*T^4 - 1.07197252E-12*T^5;
            elseif C == 35
                r = 7.98503726 - 0.116476884*T + 0.000679525068*T^2 - 0.00000198045953*T^3 + 2.88211618E-09*T^4 - 1.67488412E-12*T^5;
            end
        case "cond"
            if T < 260 || T > 390
                warning("Temperature outside range of curve fit")
            end
            if C == 30
                r = 0.0772149412 + 0.00171583459*T - 0.00000133978721*T^2;
            elseif C == 35
                r = 0.121346932 + 0.00136289223*T - 8.83981976E-07*T^2;
            end
        otherwise
            error("Unknown property '%s'", property);
    end
end