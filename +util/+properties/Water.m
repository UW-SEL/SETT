function r = Water(property, T)
    % WATER Return fluid properties of water
    %
    % T -- temperature [K]
    
    %
    % The returned property is specified with the string argument 'property',
    % which is case-insensitive and must be one of:
    %   dens -- density [kg/m3]
    %   enth -- specific enthapy [J/kg-K]
    %   cp   -- specific heat at constant pressure [J/kg-K]
    %   visc -- viscosity [Pa-s]
    %   cond -- thermal conductivity [W/m-K]
   
    % Following is assuing constant atmospheric pressure    
    property = lower(property);
    
    switch property
        case "dens"
            r = -308.062565 + 11.8774405*T - 0.0347890783*T^2 + 0.0000323261984*T^3;
        case "enth"
            r = -1.14732787E+06 + 4198.41225*T;
        case "cp"
            r = 763112.951 - 11918.8624*T + 74.7411074*T^2 - 0.23389431*T^3 + 0.000365214491*T^4 - 2.27597019E-07*T^5;
        case "visc"
            r = 1.67863264 - 0.0207808388*T + 0.0000964439032*T^2 - 1.98701027E-07*T^3 + 1.53261883E-10*T^4;
        case "cond"
            r = -4.30864379 + 0.0409646682*T - 0.00011446373*T^2 + 1.08600212E-07*T^3;
        otherwise
            error("Unknown property '%s'", property);
    end
end
