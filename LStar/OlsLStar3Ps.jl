function OlsLStar3Ps(y,x0,w,ExciseIt,z,gM,cM,gcKeep=[],NWm=0)
#OlsLStar3Ps  LSTAR LS of y on (x0,w), y = (1-G)*b1*x0 + G*b2*x0 + d*w,
#             G = 1./(1+exp.(-g*(z-c)))
#
#
#
#
#  Usage:    (theta,Stdtheta,fnOutput) = OlsLStar3Ps(y,x0,w,ExciseIt,z,gM,cM[,gcKeep[,NWm]])
#
#
#  Input:    y            Tx1, dependent variable
#            x0           Txk, regressors that have regime shifts (including deterministic ones)
#            w            Txkw, regressors that do not have regime shifts, can be empty, Array{Float64}(T,0)
#            ExciseIt     bool, if true: excise([y,x0,w,z])
#            z            Tx1, argument of G(z) function
#            gM           Ngx1, different values of g to try in a loop
#            cM           Ncx1, different values of c to try in a loop
#            gcKeep       (optional) 2x1, [g;c], if an element is a NaN, then this parameter is estimated
#            NWm          integer, Newey-West bandwidth [0]
#
#  Output:   theta        (2+2k+kw)x1, (1+2k+kw)x1 or (0+2k+kw)x1, parameter estimates:
#                                [g;c;b;d],[c;b;d],[g;b;d] or [b;d],
#                                b is a (k+k)x1 vector for x0, the first k elements are for z=-Inf
#                                and the second k elements for z=Inf
#                                d are coefficiets for w (no regimes)
#            Stdtheta     "", standard errors of theta
#            fnOutput     heterogeneous (Any[]) array with
#              [1]  Covtheta     cov(theta)
#              [2]  slopeDiff    matrix, [b tstat]
#              [3]  R2a          scalar, coefficient of determination
#              [4]  T            scalar, no of effective data points
#              [5]  gcHat        2x1, [g;c] prespecified/estimated
#              [6]  G            Tx1, value of G function at estimated parameters
#              [7]  sseM         NgxNc, sum of squared errors for different values of g and c
#              [8]  sse          scalar, loss fn value at point estimate
#              [9]  b            coeffs from traditional LS (conditional on g and c)
#              [10] Stdb_ols     standard errors according to traditional LS (conditional on g and c)
#
#
#  Calls on: excise (different versions), OlsPs, NewEst3Ps, NumJac3Ps
#
#  Notice:  (a) z is NOT standardized inside this function
#           (b) when only one of the (g,c) parameters is estimated,
#               then extrema(gM) or extrema(cM) defines the bounded
#               interval used by optimize()
#
#
#  Paul.Soderlind@unisg.ch, Jan 2013, to Julia Nov 2015
#----------------------------------------------------------------------------

  Ng = length(gM)
  Nc = length(cM)

  k  = size(x0,2)
  kw = size(w,2)

  if ExciseIt
    vv  = FindNoNaNPs(1,y,x0,w,z)                #find rows with no NaNs
    (y,x0,w,z) = (y[vv,:],x0[vv,:],w[vv,:],z[vv,:])
  end

  sseM = fill(NaN,(Ng,Nc))             #calculate sse in double loop over g and c values
  for i = 1:Ng, j = 1:Nc               #to get good starting values for optimization
    sseM[i,j] = OlsLStar3LossPs([gM[i];cM[j]],y,x0,w,z,[gM[i];cM[j]])[1]
  end   #i,j
  (i,j)         = ind2sub(size(sseM),indmin(sseM))    #minimum loss, for which i,j
  (_,_,_,par0,) = OlsLStar3Par(gcKeep,[NaN;NaN;NaN],[gM[i];cM[j]])

  if !isempty(par0)
    if length(par0) == 1
      if isnan(gcKeep[1])                            #bracket for univariate optimization
        (par0a,par0b) = (minimum(gM),maximum(gM))           #estimate g, must be positive
      else
        (par0a,par0b) = (minimum(cM),maximum(cM))           #estimate c
      end
      Sol = optimize(par->1.0 + OlsLStar3LossPs(par,y,x0,w,z,gcKeep)[1],par0a,par0b)
    else
      Sol = optimize(par->1.0 + OlsLStar3LossPs(par,y,x0,w,z,gcKeep)[1],par0,x_tol=1e-6)
    end
    parX = Optim.minimizer(Sol)
    if !Optim.converged(Sol)
      warn("no convergence")
      return
    end
  else
    parX = Float64[]
  end

  (sse,fnOutputA)   = OlsLStar3LossPs(parX,y,x0,w,z,gcKeep,true,NWm)
  (theta,Stdtheta,Covtheta,R2a,T,gcHat,G,b,Stdb_ols) = fnOutputA

  kgc        = length(theta) - (2*k + kw)           #no. of estimated pars in [g;c]
  bDiff      = fill(NaN,k)                          #calculate and test b2-b1=0
  tstatbDiff = fill(NaN,k)
  for j = 1:k
    R               = zeros(theta)
    vv              = kgc + [j;j+k]     #location of b1 and b2 for same x0[:,j]
    R[vv]           = [-1;1]
    bDiff[j]      = (R'theta)[1]
    tstatbDiff[j] = (R'theta)[1]/sqrt((R'Covtheta*R)[1])
  end
  slopeDiff = cat(2,bDiff,tstatbDiff)

  fnOutput = Any[Covtheta,slopeDiff,R2a,T,gcHat,G,sseM,sse,b,Stdb_ols]
  return theta, Stdtheta, fnOutput

end
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function OlsLStar3LossPs(par,y,x0,w,z,gcKeep=Float64[],DetailsIt=false,NWm=0)

  (g,c,) = OlsLStar3Par(gcKeep,[par;NaN],[NaN;NaN])
  (T,k)  = size(x0,1,2)

  G  = 1./(1+exp.(-(z-c)*g))
  x  = [x0.*(1-G) x0.*G w]

  (b,res,_,Covb,R2a,)   = OlsPs(y,x)
  Stdb_ols              = sqrt.(diag(Covb))
  sse                   = sum(res.^2)
  theta                 = [par;b]

  if DetailsIt
    (_,m)    = OlsLStar3MomCondPs(theta,y,x0,w,z,gcKeep)
    S0       = NewEst3Ps(m,NWm)                                    #ACov(sqrt(T)*mbar)
    #D0       = NumJac3Ps(p->OlsLStar3MomCondPs(p,y,x0,w,z,gcKeep)[1],theta,Float64[],3)  #gradient of mbar
    D0 =      ForwardDiff.jacobian(p->OlsLStar3MomCondPs(p,y,x0,w,z,gcKeep)[1],theta)
    Covtheta = inv(D0)*S0*inv(D0)'/T                        #Cov(theta)
    Stdtheta = sqrt.(diag(Covtheta))
    gcHat    = [g;c]
  else
    (Covtheta,Stdtheta,G,gcHat) = (Float64[],Float64[],Float64[],Float64[])
  end
                #  1       2       3      4  5   6   7 8  9
  fnOutput = Any[theta,Stdtheta,Covtheta,R2a,T,gcHat,G,b,Stdb_ols]
  return sse, fnOutput

end
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function OlsLStar3MomCondPs(theta,y,x0,w,z,gcKeep)   #moment conditions

  k  = size(x0,2)
  kw = size(w,2)

  (g,c,b,_,EstType) = OlsLStar3Par(gcKeep,theta,[NaN;NaN])

  G   = 1./(1+exp.(-(z-c)*g))                    #Tx1
  x   = [x0.*(1-G) x0.*G w]
  res = y - x*b

  b1 = b[1:k]
  b2 = b[k+1:2*k]

  b1_b2x0 = x0*(b2-b1)                            #Tx1
  dF_dg   = (1-G).*G.*(z-c).*b1_b2x0              #Tx1
  dF_dc   = (1-G).*G.*(-g).*b1_b2x0               #Tx1

  mg = res.*dF_dg
  mc = res.*dF_dc
  mb = res.*x

  if EstType == 1           #estimate (g,c,b)
    m = -[mg mc mb]
  elseif EstType == 2       #(c,b)
    m = -[   mc mb]
  elseif EstType == 3       #(g,b)
    m = -[mg    mb]
  elseif EstType == 4       #b
    m = -[      mb]
  else
    error("invalid case")
  end

  mbar = mean(m,1)'

  return mbar,m

end
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function OlsLStar3Par(gcKeep,theta,gcM)

  vvNaN = isnan.(gcKeep)
  if isempty(gcKeep) || all(vvNaN)       #gcKeep=[] or [NaN,NaN], estimate both g and c
    (g,c,b) = (abs(theta[1]),theta[2],theta[3:end])
    par0    = [gcM[1];gcM[2]]
    EstType = 1
  elseif vvNaN == [false;true]           #gcKeep=[1.5,NaN], don't estimate g, estimate c
    (g,c,b) = (gcKeep[1],theta[1],theta[2:end])
    par0    = gcM[2]
    EstType = 2
  elseif vvNaN == [true;false]           #gcKeep=[NaN,-0.75], estimate g, don't estimate c
    (g,c,b) = (theta[1],gcKeep[2],theta[2:end])
    par0    = gcM[1]
    EstType = 3
  elseif !any(vvNaN)                     #gcKeep=[1.5,-0.75], don't estimate g or c
    (g,c,b) = (gcKeep[1],gcKeep[2],copy(theta))
    par0    = Float64[]
    EstType = 4
  else
    error("invalid case")
  end

  return g, c, b, par0, EstType

end
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function OlsLStar3PredPs(x0,w,z,theta,gcKeep)

  (g,c,b,) = OlsLStar3Par(gcKeep,theta,[NaN;NaN])

  G  = 1./(1+exp.(-(z-c)*g))
  x1 = x0.*(1-G)
  x2 = x0.*G
  x  = [x1 x2 w]

  yHat  = x*b
  yHat2 = [zeros(x1) x2 zeros(w)]*b        #constribution of x2 only

  return yHat, yHat2, G

end
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
#function OlsLStar3LossPs(par,y,x0,w,z,gcKeep=Float64[])    #loss fn for Optim
#  sse, = OlsLStar3LossAllPs(par,y,x0,w,z,gcKeep,false)
#  sse  = 1.0 + sse
#  return sse
#end
#------------------------------------------------------------------------------


#------------------------------OLD STUFF---------------------------------------
#
#function OlsLStar3MomCondPs(theta,y,x0,w,z,gcKeep)   #just mbar from  OlsLStar3MomCondPs
#
#  mbar, = OlsLStar3MomCondPs(theta,y,x0,w,z,gcKeep)
#
#  return mbar
#
#end
#------------------------------------------------------------------------------
