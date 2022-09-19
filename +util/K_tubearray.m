function [DP_g] = K_tubearray(fluid_properties,  m_dot, D, L, N_tube, D_header)

    % K_tubearray provide the pressure drop associated with the contraction
    % and expansion effects for an array of tubes
    % from Kayes and London
    %
    % Necessary inputs are:
    % fluid_properties [call function]
    % m_dot, total mass flow rate through all tubes [kg/s]
    % D, inner diameter of tube (m)
    % L, length of tube (m)
    % N_tube, number of tubes 
    % D_header, diameter of header (m)
    
  
    %properties 
    rho_g = fluid_properties.rho;
    mu_g = fluid_properties.mu;
    A_c_tube = pi*D^2/4;                %Cross sectional area of one tube
    u_g = m_dot/(N_tube*rho_g*A_c_tube);            %velocity in tube
    Re = rho_g*u_g*D/mu_g;           %Reynolds number 
    sigma = N_tube*A_c_tube/(pi*D_header^2/4); %ratio of flow to frontal areas 
    LoverD = L / D;

    %get contraction coefficient
    if (Re>3000)
	   slopet= -0.4;
	   K=0.6435;
	   Kct0=0.54+slopet*sigma;
       Kctinf=0.40+slopet*sigma;
	   lRer1=log10(100000)-log10(3000);
   	   lRer=log10(Re)-log10(3000);
       Kc=Kct0-(Kct0-Kctinf)*(1-exp(-K*lRer));
	else
	   if (Re>2000) 
    	  slopet= -0.4;
	      K=0.6435;
	      Kct0=0.54+slopet*sigma;
  	      Kct=Kct0;
	      xstar=4*LoverD/2000;
	      Kclam0=0.42+(1.075-0.42)*(1-exp(-12.6481477*(xstar)^0.7));
	      slopel=-0.61;
	      Kcl=Kclam0+slopel*sigma;
	      Kc=Kcl+(Kct-Kcl)*(Re-2000)/(3000-2000);
	   else
	      xstar=4*LoverD/Re;
	      Kclam0=0.42+(1.075-0.42)*(1-exp(-12.6481477*(xstar)^0.7));
	      slopel=-0.61;
	      Kc=Kclam0+slopel*sigma;  
       end
    end
    
    %get expansion coefficient
    if (Re>3000) 
	   K=0.6435;
	   Ket0=1-1.97509751*sigma+(-0.13-1+1.97509751)*sigma^2;
       Ketinf=1-1.97509751*sigma+(0-1+1.97509751)*sigma^2;
	   lRer1=log10(100000)-log10(3000);
   	   lRer=log10(Re)-log10(3000);
       Ke=Ket0-(Ket0-Ketinf)*(1-exp(-K*lRer));
	else
	   if(Re>2000) 
  	      K=0.6435;
	      Ket=1-1.97509751*sigma+(-0.13-1+1.97509751)*sigma^2;
	      xstar=4*LoverD/2000;
	      Kel1=-0.67*(1-exp(-8.50924729*(xstar)^0.6));
	      Kel=1-1.97509751*sigma+(Kel1-1+1.97509751)*sigma^2;
	      Ke=Kel+(Ket-Kel)*(Re-2000)/(3000-2000);	
	   else
	      xstar=4*LoverD/Re;
	      Kel1=-0.67*(1-exp(-8.50924729*(xstar)^0.6));
	      Ke=1-1.97509751*sigma+(Kel1-1+1.97509751)*sigma^2;
       end
    end
    DP_g = (Kc+Ke)*rho_g*u_g^2/2;
