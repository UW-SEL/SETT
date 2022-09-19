function [Q_dot] = conduction(material, T_h, T_c, geometry, method, gv)
    % conduction evaluates the conduction heat transfer through a 1-D
    % geometry
    %
    % Arguments:
    %   material -- a string corresponding to a material recognized by the
    %   utility function Solid
    %   T_h        -- hot end temperature [K]
    %   T_c        -- cold end temperature [K]
    %   geometry   -- string representing the geometry
    %       "plane" : plane wall
    %       "tapcyl" : a cylinder with thickness that varies linearly from
    %           end-to-end
    %   method     -- string indicating the method to use
    %       "avgk" : use average conductivity evaluated at avg. temp
    %       "intavgk" : use the integrated average conductivity
    %   gv         -- vector of geometric parameters (depends on geometry)
    %       for "plane" : gv(1) = A_c, cross-sectional area (m^2)
    %                     gv(2) = L, length (m)
    %       for "tapcyl" : gv(1) = R_in, inner radius (m)
    %                      gv(2) = th_c, thickness at cold end (m)
    %                      gv(3) = th_h, thickness at hot end (m)
    %                      gv(4) = L, length (m)
    %
    % Returns:
    %   Q_dot - rate of conduction heat transfer (W)
    
    %determine conductivity to use
     
    switch method
        case "avgk"
            [~, ~, k_avg] = util.properties.Solid(material, (T_h+T_c)/2);
        case "intavgk" 
            N_int=101;
            Tv=linspace(T_c,T_h,N_int);
            for i=1:N_int
               [~,~,kv(i)]=util.properties.Solid(material, Tv(i)); 
            end
            k_avg = trapz(Tv,kv)/(T_h-T_c);            
        otherwise
            error("method string in conduction utility function is unrecognized");
    end 
    
    switch geometry
        case "plane"
            SF=gv(1)/gv(2);
        case "tapcyl"
            SF=(2*pi*gv(1)*(gv(3)-gv(2)))/(gv(4)*log(gv(3)/gv(2)));
    end
    Q_dot=SF*k_avg*(T_h-T_c);
    
end
            
    
    