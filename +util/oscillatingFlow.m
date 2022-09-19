function [MF_DP, MF_h] = oscillatingFlow(fluid_properties, D_h, f, u_max)
    % OSCILLATINGFLOW Provide the friction factor and Nusselt number for oscillating flow through a pipe
    %
    % fluid_properties - a fluid property object
    % D_h - hydraulic diameter (m)
    % f - frequency (Hz)
    % u_max - maximum velocity (m/s)
    
    
    omega = 2*pi*f;  %angular frequency in rad/s
    Va = fluid_properties.rho*omega*D_h^2/(4*fluid_properties.mu);  %Valensi number
    Re = fluid_properties.rho*u_max*D_h/fluid_properties.mu;  %Reynolds number based on maximum velocity
    Pr = fluid_properties.mu*fluid_properties.CP/fluid_properties.k; %molecular Prandtl number
    Re_l = 2300;  %critical Reynolds number
    Va_c = 10;  %critical Velensi number
    Re_trans = Re_l*max(sqrt(Va/Va_c),1); %transitional Reynolds number
    if (Re<Re_trans) 
        regime='laminar';
        MF_DP = s_lam(Va)/s_lam(0);
        MF_h = Nu_lam(Va,Pr)/Nu_lam(0,Pr);
    else
        regime='turbulent';
        MF_DP = 1;
        MF_h = 1;
    end
    
    function r1 = s_lam(Va)
        if(Va<32)
            r1=4;
        else
            r1=sqrt(Va/2);
        end
    end

    function r2 = Nu_lam(Va,Pr)
        arg = sqrt(2*Va*Pr);
        if(arg<6)
            r2=6;
        else
            r2=arg;
        end
    end    
    
end
