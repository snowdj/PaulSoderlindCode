function BondNSxEstPs(par0,Q,tm,c,s0,ytmLoss=0,weight=1)
#BondNSxEstPs    Estimates parameters in (extended) Nelson-Siegel yield curve model by
#              non-linear least squares (minimizing squared differences between
#              actual and fitted bond prices or yield to maturities).
#
#
#
#  Usage:    NSb = BondNSxEstPs(par0,Q,tm,c,s0[,ytmLoss[,weight]])
#
#
#  Input:    par0       4x1 or 6x1 vector, initial guess of paremeters
#                         if 4x1: standard NS with par0 = [b0,b1,b2,tau]
#                         if 6x1: extended NS with par0 = [b0,b1,b2,tau,b3,tau2]
#            Q          nx1 vector, data on bond prices, eg. 1.01
#            tm         nx1 vector, data on time to maturity (in years), eg. 2.54
#            c          nx1 vector, data on bond coupons, eg. 0.06
#            s0         scalar, restricted value of short rate:
#                       if [] no restriction, else b0 + b1 = s0 is imposed
#            ytmLoss    scalar, scalar, 0: mimimize squared price errors;
#                                       1: minimize squared ytm errors (default 0)
#            weight    scalar or nx1 vector, weights in the loss function
#
#  Output:   NSb        4x1 or 6x1 vector, estimated parameters
#
#
#
#  Note:     For more details, see
#            (a) Svensson (1995), "Estimating Forward Interest Rates with
#                the Extended Neolson & Siegel Method," Quarterly Review,
#                Sveriges Riksbank, 1995:3, 13-26.
#            (b) Soderlind and Svensson (1997), "New Techniques to Extract
#                Market Expectations from Financial Instruments,"
#                Journal of Monetary Economics 40, 383-429.
#
#
#  Uses:  Optim
#
#
#
#  Paul.Soderlind@unisg.ch, April 2002, to Julia Nov 2015
#------------------------------------------------------------------------------

  Qtc = [Q tm c]

  if length(par0) == 4          #standard Nelson-Siegel
    if !isempty(s0)             #b1 = s0 - b0 is then imposed by BondNSxLossPs
      par0 = par0([1;3;4])
    end
  elseif length(par0) == 6      #extended Nelson-Siegel
    if !isempty(s0)             #b1 = s0 - b0 is imposed by BondNSxLossPs
      par0 = par0[[1;3;4;5;6]]
    end
  end

  Sol = optimize(b->BondNSxLossPs(b,Qtc,s0,ytmLoss,weight),par0,ftol=1e-12,iterations=10000)
  NSb = Sol.minimum
  #println(Sol)
  if !Sol.f_converged
    warn("no convergence")
    return
  end

  if length(NSb) == 3
    NSb[[1;3]] = abs(NSb[[1;3]])
  elseif length(NSb) == 4
    NSb[[1;4]] = abs(NSb[[1;4]])
  elseif length(NSb) == 5
    NSb[[1;3;5]] = abs(NSb[[1;3;5]])
  elseif length(NSb) == 6
    NSb[[1;4;6]] = abs(NSb[[1;4;6]])
  end

  if length(NSb) == 3          #standard NS with restriction
    NSb = [NSb[1]; (s0-NSb[1]); NSb[2:3]]
  elseif length(NSb) == 5      #extended NS with restriction
    NSb = [NSb[1]; (s0-NSb[1]); NSb[2:5]]
  end

  return NSb

end
#----------------------------------------------------------------------------


#------------------------------------------------------------------------------
function BondNSxLossPs(b,Qtc,s0,ytmLoss=0,weight=1)
#BondNSxLossPs    Defines loss function for bond prices in extended Nelson-Siegel model.
#                 Used for estimation of the parameters in the model by minimizing
#                 Loss (squared price deviations, possibly with weights).
#
#
#  Usage:    Loss = BondNSxLossPs(b,Qtc,s0,ytmLoss,weight)    or
#                 = BondNSxLossPs(b,Qtc,s0,ytmLoss)           or
#                 = BondNSxLossPs(b,Qtc,s0)
#
#  Input:    b         3x1, 4x1, 5x1, or 6x1 vector with parameters in Nelson-Siegel model
#                        if 3x1: [b0,b2,tau], NS with restriction that b1 = g_s0 - b0
#                        if 4x1: [b0,b1,b2,tau], NS without restrictions
#                        if 5x1: [b0,b2,tau,b3,tau2], extended NS with restriction that b1 = g_s0 - b0
#                        if 6x1: [b0,b1,b2,tau,b3,tau2], extended NS without restrictions
#            Qtc       nx3 matrix, data on [bond prices,time to maturity,coupons]. Use ytm instead
#                        of bond prices if ytmLoss==1
#            s0        scalar, restricted value of short rate
#            ytmLoss   scalar, 0: mimimize squared price errors;
#                      1: minimize squared ytm errors (default 0)
#            weight    scalar or nx1 vector, weights in the loss function
#
#  Output:   Loss    scalar, sum of squared differences between implied and actual bond
#                    prices (or yields)
#
#
#
#  Note:     For more details, see
#            (a) Svensson (1995), "Estimating Forward Interest Rates with
#                the Extended Nelson & Siegel Method," Quarterly Review,
#                Sveriges Riksbank, 1995:3, 13-26.
#            (b) Soderlind and Svensson (1997), "New Techniques to Extract
#                Market Expectations from Financial Instruments,"
#                Journal of Monetary Economics 40, 383-429.
#
#
#  Calls on: BondNSxPs
#
#  Paul.Soderlind@unisg.ch, 8 April 2002
#------------------------------------------------------------------------------

  Q  = Qtc[:,1]           #data on bond prices
  tm = Qtc[:,2]           #data on time to maturity, fraction of years
  c  = Qtc[:,3]           #data on coupons

  n = length(c)           #number of bonds

  if length(b) == 3             #standard Nelson-Siegel with restriction b1 = s0-b0
    b0   = abs(b[1])
    b1   = s0 - b0
    b2   =     b[2]
    tau  = abs(b[3])
    b3   = 0.0
    tau2 = 1.0
  elseif length(b) == 4         #standard Nelson-Siegel
    b0   = abs(b[1])
    b1   =     b[2]
    b2   =     b[3]
    tau  = abs(b[4])
    b3   = 0.0
    tau2 = 1.0
  elseif length(b) == 5         #extended Nelson-Siegel with restriction b1 = s0 - b0
    b0   = abs(b[1])
    b1   = s0 - b0
    b2   =     b[2]
    tau  = abs(b[3])
    b3   =     b[4]
    tau2 = abs(b[5])
  elseif length(b) == 6         #extended Nelson-Siegel
    b0   = abs(b[1])
    b1   =     b[2]
    b2   =     b[3]
    tau  = abs(b[4])
    b3   =     b[5]
    tau2 = abs(b[6])
  end

  QNS = fill(NaN,n)
  for i = 1:n                            #loop over bonds
    ti  = collect(mod(tm[i],1):tm[i])    #vector for coupon stream
    vv0 = ti .> 0                        #get rid of zero time to coupon payment
    ti  = ti[vv0]
    (s,f,d) = BondNSxPs(ti,b0,b1,b2,tau,b3,tau2)  #NSx: spot, forward, discount fn
    QNS[i]  = sum(d.*c[i]) + d[end]               #fitted bond price
    if ytmLoss == 1
      QNS_i = BondYieldToMat3Ps(QNS[i],c[i],ti,1,0.05,1e-7)[1]  #fitted ytm
      QNS[i] = QNS_i[1]  #fitted ytm
    end
  end
  Loss = 1.0 + 100*sum( weight.*(QNS - Q).^2 )  #weighted sum of squared deviations of fitted from actual

  return Loss

end
#------------------------------------------------------------------------------
