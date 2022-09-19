function[SHL]=shuttleheattransfer(D, h, L, s, omega, solid, DP, engine, phi, flag)

%shuttleheattransfer models shuttle heat transfer using the solution found
%in Urieli and Berchowitz, 1984
%
% Inputs
% D = diameter of bore (m)
% h = cylinder-to-piston gap (m)
% L = gap length (m)
% s = stroke (m)
% omega = angular frequency (rad/s)
% solid = material for cylinder (must be one of those in solid.m)
% DP = pressure amplitude (Pa)
% engine = instance of the engine
% phi = phase angle between pressure and volume (rad)
% flag = optional flag (=1 use both terms, default, =2 use only first term
% and neglect enthalpy term)

if (nargin<10) 
    flag=1;
end

T_avg = (engine.T_k + engine.T_l)/2;  %average temperature
Y = (engine.T_l - engine.T_k)/L;%temperature gradient
fluidProps = engine.fluid.allProps(T_avg, engine.P_ave); %get fluid properties at average T and P
kg = fluidProps.k;  %gas conductivity at avg. temp
NDt = kg*s^2*Y; %non-dimensionalizing shuttle heat transfer

SHL1 = pi*D*kg*s^2*Y/(h*8);  %1st term in solution - related to shuttle heat transfer

R = engine.P_ave/(fluidProps.rho*T_avg);  %estimate the gas constant
gamma = fluidProps.CP/(fluidProps.CP-R);  %estimate gamma
[rhos, cs, ks] = util.properties.Solid(solid, T_avg); %get properties of cylinder
alphas = ks/(rhos*cs);  %thermal diffusivity (m^2/s)
w = sqrt(omega/(2*alphas));  %inverse of thermal penetration depth (1/m)
SHL2 = pi*D*DP*h*s*omega*(gamma/(gamma-1)*log(engine.T_l/engine.T_k)*(1/2-kg/(w*h*ks))-1/2)*sin(phi)/4; %2nd term - related to enthalpy flow

if(flag==1) 
    SHL = SHL1 + SHL2;
else
    SHL=SHL1;
end
    


%SHL_bar = SHL/NDt  %dimensionless size 
%hoverD = h/D  %gap-to-diameter ratio

