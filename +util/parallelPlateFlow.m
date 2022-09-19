function [DP_g, h] = parallelPlateFlow(fluidProps,u_m, L, D_h)
    % parallelPlateFlow Provide the pressure drop and heat transfer for flow through a parallel plate configuartion 
    %
    % Necessary inputs are:
    %fluid properties[call function]
    %Bulk velocity [m/s]
    %Reynolds number [-]
    %L, length of regenerator [m]
    %D_h, hydraulic diameter of the passages formed by the gaps [m]

    cp_g = fluidProps.CP;
    rho_g = fluidProps.rho;
    mu_g = fluidProps.mu;
    k_g = fluidProps.k;
    Pr_g = mu_g * cp_g / k_g;
    Re = u_m*D_h*rho_g/mu_g;
            
    if(Re<2000)
        fR_fd=24;
        x_plus=L/D_h/Re;
        fR=3.44/sqrt(x_plus)+(1.25/(4*x_plus)+fR_fd-3.44/sqrt(x_plus))/(1+0.00021*x_plus^(-2));
        f=4*fR/Re;

        Nusselt_T_fd=7.541;
        x_star=x_plus/Pr_g;
        lnx_star=log(x_star);
        a_T=0.0357122;
        b_T=0.940362;
        DNusselt_T=a_T*exp(-b_T*lnx_star);
        if(Pr_g>0.72)
            DNurat=0.6847+0.3153*exp(-1.26544559*(log(Pr_g)-log(0.72)));
        else
            DNurat=1.68-0.68*exp(0.32*(log(Pr_g)-log(0.72)));
        end
        Nusselt=Nusselt_T_fd+DNurat*DNusselt_T;
    else
        if(Re<3000)
            fR_fd=24;
            x_plus=L/D_h/2000;
            fR=3.44/sqrt(x_plus)+(1.25/(4*x_plus)+fR_fd-3.44/sqrt(x_plus))/(1+0.00021*x_plus^(-2));
            f_lam=4*fR/2000;

            Nusselt_T_fd=7.541;
            x_star=x_plus/Pr_g;
            lnx_star=log(x_star);
            a_T=0.0357122;
            b_T=0.940362;
            DNusselt_T=a_T*exp(-b_T*lnx_star);
            if(Pr_g>0.72)
                DNurat=0.6847+0.3153*exp(-1.26544559*(log(Pr_g)-log(0.72)));
            else
                DNurat=1.68-0.68*exp(0.32*(log(Pr_g)-log(0.72)));
            end
            Nusselt_lam=Nusselt_T_fd+DNurat*DNusselt_T;

            f_turb=(-0.001570232/log(3000)+0.394203137/log(3000)^2+2.534153311/log(3000)^3)*4;
            Nusselt_turb= ((f_turb/8)*(3000-1000)*Pr_g)/(1+12.7*sqrt(f_turb/8)*(Pr_g ^(2/3)-1));
            wt=(Re-2000)/(3000-2000);
            f=f_lam+wt*(f_turb-f_lam);
            Nusselt=Nusselt_lam+wt*(Nusselt_turb-Nusselt_lam);
        else
            f=(-0.001570232/log(Re)+0.394203137/log(Re)^2+2.534153311/log(Re)^3)*4;
            Nusselt= ((f/8)*(Re-1000)*Pr_g)/(1+12.7*sqrt(f/8)*(Pr_g ^(2/3)-1));
        end
    end
    h=Nusselt*k_g/D_h;
    DP_g=f*L/D_h*rho_g*u_m^2/2;