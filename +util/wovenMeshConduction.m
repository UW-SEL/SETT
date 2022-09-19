function[k_e]=wovenMeshConduction(d, pitch, t_mesh, k_g, k_s)

%wovenMeshConduction implements ths model presented in 
%
% Chang, W.S., "Porosity and Effective Thermal Conductivity of Wire
% Screens", J. Heat Transfer, Vol. 112, Feb. (1990).

%CHANGED TO Alexander (1972)
%
% to estimate the effective conductivity of a woven mesh screen.
%
% INPUTS
% d = wire diameter (m)
% pitch = wires/length (1/m)
% t_mesh = thickness of one mesh (m)
%    set to 2*d for perfect stacking
% k_g = conductivity of the fluid (W/m-K)
% k_s = conductivity of the solid (W/m-K)

%     w_mesh = 1/pitch-d; %size of opening
%     A_mesh = d/w_mesh;  %diameter-to-opening ratio
%     B_mesh = d/t_mesh;
%     alpha_m = 0.7;  %approximate median value from Figure 4
%     if (20<(k_s/k_g)) && ((k_s/k_g)<300)
%         k_e = k_g/(1+A_mesh)^2 *(alpha_m^2*A_mesh*((alpha_m*A_mesh/(alpha_m - pi*B_mesh*(1-k_g/k_s)/2) ...
%             + 2*(1+A_mesh*(1-alpha_m))/(alpha_m - pi*B_mesh*(1-k_g/k_s)/4)) + (1+A_mesh*(1-alpha_m)^2))); 
%     else
%         k_e = k_g/(1+A_mesh)^2 *(alpha_m^2*A_mesh*((alpha_m*A_mesh/(alpha_m - pi*B_mesh*(1-k_g/k_s)/2) ...
%                     + 2*(1+A_mesh*(1-alpha_m))/(alpha_m - pi*B_mesh*(1-k_g/k_s)/4)) + (1+A_mesh*(1-alpha_m)^2))); 
%     end

    x_t = 1 / (pitch * d);
    phi = 1 - pi / (4 * x_t);
 	k_e = k_g*(k_s/k_g)^((1-phi)^0.59);

