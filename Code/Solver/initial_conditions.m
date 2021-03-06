function sol_init = initial_conditions(psi0,params,vectors,matrices)
% This function creates a vector containing a steady-state solution to the 
% initial problem. The inputs are structures containing the parameters,
% vectors and matrices needed by the solver.

% Parameter input
[chi, kH, kE, Verbose] = struct2array(params, {'chi','kH','kE','Verbose'});
[x, xE, xH] = struct2array(vectors, {'x','xE','xH'});

% Define uniform profiles for the ion vacancy density and electric potential
P_init    = ones(size(x));
phi_init  = zeros(size(x));

% Compute profiles for the carrier concentrations from a quasi-steady BVP
y_guess = bvpinit(x',@(x) [kH*x+kE*(1-x)/chi; 0*x; chi*kH*x+kE*(1-x); 0*x]);
sol = bvp4c(@(x,y) yode(x,y,params),@(ya,yb) ybcs(ya,yb,params),y_guess);
solx = deval(sol,x'); p_init = solx(1,:)'; n_init = solx(3,:)';

% Define uniform profiles for the electric potential and carrier
% concentrations across the TLs
phiE_init = zeros(size(xE));
nE_init   = ones(size(xE));
phiH_init = zeros(size(xH));
pH_init   = ones(size(xH));

% Combine the initial conditions into one vector to pass to fsolve
sol_init  = [P_init; phi_init; n_init; p_init; ... % perovskite
             phiE_init; nE_init; ... % electron transport layer
             phiH_init; pH_init]; % hole transport layer
          
% Define the settings for the call to fsolve
fsoptions = optimoptions('fsolve','MaxIterations',20);
if Verbose, fsoptions.Display = 'iter'; else, fsoptions.Display = 'off'; end
fsoptions.JacobPattern = Jac(params,'init');

% Use the initial guess to obtain a steady-state solution
sol_init = fsolve(@(u) RHS(0,u,psi0,params,vectors,matrices,'init'), ...
    sol_init,fsoptions);

% Ensure all the algebraic equations are satisfied as exactly as possible
sol_init = apply_Poisson(sol_init,params,vectors,matrices);

end



% Quasi-steady BVP for the carrier concentrations
% y(1) = p(x), y(2) = jp(x) = -Kp*dp/dx, y(3) = n(x), y(4) = jn(x) = Kn*dn/dx
function dpdx = yode(x,y,params)
[G, R, Kp, Kn] = struct2array(params,{'G','R','Kp','Kn'});
dpdx = [-y(2)/Kp; ...
        G(x,0)-R(y(3),y(1),1); ...
        y(4)/Kn; ...
        -(G(x,0)-R(y(3),y(1),1))];
end
function res = ybcs(ya,yb,params)
[kH, Rl, kE, Rr] = struct2array(params,{'kH','Rl','kE','Rr'});
res = [yb(1)-kH; ...
       ya(2)+Rl(1,ya(1)); ...
       ya(3)-kE; ...
       yb(4)+Rr(yb(3),1)];
end