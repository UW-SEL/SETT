function [rho, c, k] = Solid(material, T)
    % SOLID Provide material properties of a solid
    %
    % Solid material properties are provided from EES correlations including the
    % melting temperature as an  upper limit.
    %
    % Arguments:
    %   material -- one of: 
    %   "Stainless Steel", 
    %   "SS304"
    %   "Stellite21"
    %   "Inconel", 
    %   "Titanium", 
    %   "Nickel"
    %   "AISI1010"
    %   "Multimet"
    %   T        -- temperature [K]
    %
    % Returns:
    %   rho - density (kg/m^3)
    %   c - specific heat capacity (J/kg-K)
    %   k - thermal conductivity (W/m-K)
    
    switch material
        case "Multimet"
            c=104;
            k=8.192475 + 0.0135*T;
            rho = 8200;
            if ((T<300)|(T>1100))
                warning("Temperature out of range in solid for Multimet");
            end
        
        case "SS304"
            logT = log10(T);
            c=-11549.0859 + 12710.7552*logT - 4526.51327*logT^2 + 546.916742*logT^3;
            k=9.47798456 + 0.0184785464*T - 0.00000251026252*T^2;
            rho = 7780;
            if ((T<200)|(T>1500))
                warning("Temperature out of range in solid for SS304");
            end
            
        case "Stellite21"
            c=(0.336867432 + 0.000331998664*T - 7.24140327E-08*T^2)*1000;
            k=8.29133436 + 0.0160954003*T;
            rho = 8330;
            if ((T<200)|(T>1500))
                warning("Temperature out of range in solid for Stellite21");
            end       
            
        case "Stainless Steel"
            k = 10.9462 + 0.0144304*T;
            if (200<T) && (T<600)
                rho = 7829;
                c = 230.718 + 1.06092 * T - 0.000883834*(T)^2;
            elseif (600<T) && (T<1500)
                rho = 7780;
                c = 470.247 + 0.141145*T;
            elseif T>1500
                call warning("Temperature out of range");
            end
        
        case "Inconel"
            k = 6.35032+0.0163375*T;
            rho = 8126;
            if (290<T) && (T<1100)
                c = 495.3 - 0.2142 * T + 0.0002775 * (T)^2;
            elseif (1100<T) && (T<1200)
                c = 600;
            elseif T>1200
                call warning("Temperature out of range");
            end
        
        case "Titanium"
            if (273<T) && (T<1000)
                rho = 4500;
                c = 414.475 + 0.366528 * T +  - 0.000112337 * (T)^2;
                if (T < 600)
                    k = 28.5385 - 0.0297555*T+0.0000246091*(T)^2;
                else 
                    k = 18.6534 - 0.00113593*T + 0.00000329958*(T)^2;
                end
            elseif (1000<T) && (T<1500)
                rho = 4400;
                k = 18.6534 - 0.00113593*T + 0.00000329958*(T)^2;
                c = 682.521315 - 0.0275726689*(T) + 0.0000200485973*(T)^2;
            elseif T>1500
                call warning("Temperature out of range");
            end
        
        case "Nickel"
            if (273<T) && (T<1500)
                rho = 8730;
                c = 429.713 + 0.131156*T;
                if (T<600)
                    k = 113.695 +0.0813436*T;
                else
                    k = 58.3779 + 0.00746708*T+0.00000596777*(T)^2;
                end
            elseif T>1500
                call warning("Temperature out of range");
            end
            
        case "AISI1010"
            if (273<T) && (T<1200)
                rho = 7848;
                c=658.536097 - 1.07853053*T + 0.00147061346*T^2;
                k=48.7192977 + 0.00630263836*T - 0.000026552446*T^2;
            elseif T>1200
                call warning("Temperature out of range");
            end
        otherwise
            error("material in utility function Solid is unrecognized");
    end