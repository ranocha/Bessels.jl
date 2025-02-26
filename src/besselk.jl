#    Modified Bessel functions of the second kind of order zero and one
#                       besselk0, besselk1
#
#    Scaled modified Bessel functions of the second kind of order zero and one
#                       besselk0x, besselk1x
#
#    (Scaled) Modified Bessel functions of the second kind of order nu
#                       besselk, besselkx
#
#
#    Calculation of besselk0 is done in two branches using polynomial approximations [1]
#
#    Branch 1: x < 1.0 
#              besselk0(x) + log(x)*besseli0(x) = P7(x^2)
#                            besseli0(x) = [x/2]^2 * P6([x/2]^2) + 1
#    Branch 2: x >= 1.0
#              sqrt(x) * exp(x) * besselk0(x) = P22(1/x) / Q2(1/x)
#    where P7, P6, P22, and Q2 are 7, 6, 22, and 2 degree polynomials respectively.
#
#
#
#    Calculation of besselk1 is done in two branches using polynomial approximations [2]
#
#    Branch 1: x < 1.0 
#              besselk1(x) - log(x)*besseli1(x) - 1/x = x*P8(x^2)
#                            besseli1(x) = [x/2]^2 * (1 + 0.5 * (*x/2)^2 + (x/2)^4 * P5([x/2]^2))
#    Branch 2: x >= 1.0
#              sqrt(x) * exp(x) * besselk1(x) = P22(1/x) / Q2(1/x)
#    where P8, P5, P22, and Q2 are 8, 5, 22, and 2 degree polynomials respectively.
#
#
#    The polynomial coefficients are taken from boost math library [3].
#    Evaluation of the coefficients using Remez.jl is prohibitive due to the increase
#    precision required in ArbNumerics.jl. 
#
#    Horner's scheme is then used to evaluate all polynomials.
#
#    Calculation of besselk and besselkx can be done with recursion starting with
#    besselk0 and besselk1 and using upward recursion for any value of nu (order).
#
#                    K_{nu+1} = (2*nu/x)*K_{nu} + K_{nu-1}
#
#    When nu is large, a large amount of recurrence is necesary.
#    We consider uniform asymptotic expansion for large orders to more efficiently
#    compute besselk(nu, x) when nu is larger than 100 (Let's double check this cutoff)
#    The boundary should be carefully determined for accuracy and machine roundoff.
#    We use 10.41.4 from the Digital Library of Math Functions [5].
#    This is also 9.7.8 in Abramowitz and Stegun [6].
#    K_{nu}(nu*z) = sqrt(pi / 2nu) *exp(-nu*n)/(1+z^2)^1/4 * sum((-1^k)U_k(p) /nu^k)) for k=0 -> infty
#    The U polynomials are the most tricky. They are listed up to order 4 in Table 9.39
#    of [6]. For Float32, >=4 U polynomials are usually necessary. For Float64 values,
#    >= 8 orders are needed. However, this largely depends on the cutoff of order you need.
#    For moderatelly sized orders (nu=50), might need 11-12 orders to reach good enough accuracy
#    in double precision. 
#
#    However, calculation of these higher order U polynomials are tedious. These have been hand
#    calculated and somewhat crosschecked with symbolic math. There could be errors. They are listed
#    in src/U_polynomials.jl as a reference as higher orders are impossible to find while being needed for any meaningfully accurate calculation.
#    For large orders these formulas will converge much faster than using upward recurrence.
#
#    
# [1] "Rational Approximations for the Modified Bessel Function of the Second Kind 
#     - K0(x) for Computations with Double Precision" by Pavel Holoborodko     
# [2] "Rational Approximations for the Modified Bessel Function of the Second Kind 
#     - K1(x) for Computations with Double Precision" by Pavel Holoborodko
# [3] https://github.com/boostorg/math/tree/develop/include/boost/math/special_functions/detail
# [4] "Computation of Bessel Functions of Complex Argument and Large Order" by Donald E. Amos
#      Sandia National Laboratories
# [5] https://dlmf.nist.gov/10.41
# [6] Abramowitz, Milton, and Irene A. Stegun, eds. Handbook of mathematical functions with formulas, graphs, and mathematical tables. 
#     Vol. 55. US Government printing office, 1964.
#

"""
    besselk0(x::T) where T <: Union{Float32, Float64}

Modified Bessel function of the second kind of order zero, ``K_0(x)``.
"""
function besselk0(x::T) where T <: Union{Float32, Float64}
    x <= zero(T) && return throw(DomainError(x, "`x` must be nonnegative."))
    if x <= one(T)
        a = x * x / 4
        s = muladd(evalpoly(a, P1_k0(T)), inv(evalpoly(a, Q1_k0(T))), T(Y_k0))
        a = muladd(s, a, 1)
        return muladd(-a, log(x), evalpoly(x * x, P2_k0(T)))
    else
        s = exp(-x / 2)
        a = muladd(evalpoly(inv(x), P3_k0(T)), inv(evalpoly(inv(x), Q3_k0(T))), one(T)) * s / sqrt(x)
        return a * s
    end
end
"""
    besselk0x(x::T) where T <: Union{Float32, Float64}

Scaled modified Bessel function of the second kind of order zero, ``K_0(x)*e^{x}``.
"""
function besselk0x(x::T) where T <: Union{Float32, Float64}
    x <= zero(T) && return throw(DomainError(x, "`x` must be nonnegative."))
    if x <= one(T)
        a = x * x / 4
        s = muladd(evalpoly(a, P1_k0(T)), inv(evalpoly(a, Q1_k0(T))), T(Y_k0))
        a = muladd(s, a, 1)
        return muladd(-a, log(x), evalpoly(x * x, P2_k0(T))) * exp(x)
    else
        return muladd(evalpoly(inv(x), P3_k0(T)), inv(evalpoly(inv(x), Q3_k0(T))), one(T)) / sqrt(x)
    end
end
"""
    besselk1(x::T) where T <: Union{Float32, Float64}

Modified Bessel function of the second kind of order one, ``K_1(x)``.
"""
function besselk1(x::T) where T <: Union{Float32, Float64}
    x <= zero(T) && return throw(DomainError(x, "`x` must be nonnegative."))
    if x <= one(T)
        z = x * x
        a = z / 4
        pq = muladd(evalpoly(a, P1_k1(T)), inv(evalpoly(a, Q1_k1(T))), Y_k1(T))
        pq = muladd(pq * a, a, (a / 2 + 1))
        a = pq * x / 2
        pq = muladd(evalpoly(z, P2_k1(T)) / evalpoly(z, Q2_k1(T)), x, inv(x))
        return muladd(a, log(x), pq)
    else
        s = exp(-x / 2)
        a = muladd(evalpoly(inv(x), P3_k1(T)), inv(evalpoly(inv(x), Q3_k1(T))), Y2_k1(T)) * s / sqrt(x)
        return a * s
    end
end
"""
    besselk1x(x::T) where T <: Union{Float32, Float64}

Scaled modified Bessel function of the second kind of order one, ``K_1(x)*e^{x}``.
"""
function besselk1x(x::T) where T <: Union{Float32, Float64}
    x <= zero(T) && return throw(DomainError(x, "`x` must be nonnegative."))
    if x <= one(T)
        z = x * x
        a = z / 4
        pq = muladd(evalpoly(a, P1_k1(T)), inv(evalpoly(a, Q1_k1(T))), Y_k1(T))
        pq = muladd(pq * a, a, (a / 2 + 1))
        a = pq * x / 2
        pq = muladd(evalpoly(z, P2_k1(T)) / evalpoly(z, Q2_k1(T)), x, inv(x))
        return muladd(a, log(x), pq) * exp(x)
    else
        return muladd(evalpoly(inv(x), P3_k1(T)), inv(evalpoly(inv(x), Q3_k1(T))), Y2_k1(T)) / sqrt(x)
    end
end

#              Modified Bessel functions of the second kind of order nu
#                           besselk(nu, x)
#
#    A numerical routine to compute the modified Bessel function of the second kind K_{ν}(x) [1]
#    for real orders and arguments of positive or negative value. The routine is based on several
#    publications [2-8] that calculate K_{ν}(x) for positive arguments and orders where
#    reflection identities are used to compute negative arguments and orders.
#
#    In particular, the reflectance identities for negative orders I_{−ν}(x) = I_{ν}(x).
#    For negative arguments of integer order, Kn(−x) = (−1)^n Kn(x) − im * π In(x) is used and for
#    noninteger orders, Kν(−x) = exp(−iπν)*Kν(x) − im π Iν(x) is used. For negative orders and arguments the previous identities are combined.
#
#    The identities are computed by calling the `besseli_positive_args(nu, x)` function which computes K_{ν}(x)
#    for positive arguments and orders. For large orders, Debye's uniform asymptotic expansions are used.
#    For small value and when nu > ~x the power series is used. The rest of the values are computed using slightly different methods.
#    The power series for besseli is modified to give both I_{v} and I_{v-1} where the ratio K_{v+1} / K_{v} is computed using continued fractions [8].
#    The wronskian connection formula is then used to compute K_v.

# [1] http://dlmf.nist.gov/10.27.E4
# [2] Amos, Donald E. "Computation of modified Bessel functions and their ratios." Mathematics of computation 28.125 (1974): 239-251.
# [3] Gatto, M. A., and J. B. Seery. "Numerical evaluation of the modified Bessel functions I and K." 
#     Computers & Mathematics with Applications 7.3 (1981): 203-209.
# [4] Temme, Nico M. "On the numerical evaluation of the modified Bessel function of the third kind." 
#     Journal of Computational Physics 19.3 (1975): 324-337.
# [5] Amos, DEv. "Algorithm 644: A portable package for Bessel functions of a complex argument and nonnegative order." 
#     ACM Transactions on Mathematical Software (TOMS) 12.3 (1986): 265-273.
# [6] Segura, Javier, P. Fernández de Córdoba, and Yu L. Ratis. "A code to evaluate modified bessel functions based on thecontinued fraction method." 
#     Computer physics communications 105.2-3 (1997): 263-272.
# [7] Geoga, Christopher J., et al. "Fitting Mat\'ern Smoothness Parameters Using Automatic Differentiation." 
#     arXiv preprint arXiv:2201.00090 (2022).
# [8] Cuyt, A. A., Petersen, V., Verdonk, B., Waadeland, H., & Jones, W. B. (2008). 
#     Handbook of continued fractions for special functions. Springer Science & Business Media.
#

"""
    besselk(x::T) where T <: Union{Float32, Float64}

Modified Bessel function of the second kind of order nu, ``K_{nu}(x)``.
"""
besselk(nu::Real, x::Real) = _besselk(nu, float(x))

_besselk(nu, x::Float16) = Float16(_besselk(nu, Float32(x)))

function _besselk(nu, x::T) where T <: Union{Float32, Float64}
    isinteger(nu) && return _besselk(Int(nu), x)
    abs_nu = abs(nu)
    abs_x = abs(x)

    if x >= 0
        return besselk_positive_args(abs_nu, abs_x)
    else
        return throw(DomainError(x, "Complex result returned for real arguments. Complex arguments are currently not supported"))
        #return cispi(-abs_nu)*besselk_positive_args(abs_nu, abs_x) - besseli_positive_args(abs_nu, abs_x) * im * π
    end
end
function _besselk(nu::Integer, x::T) where T <: Union{Float32, Float64}
    abs_nu = abs(nu)
    abs_x = abs(x)
    sg = iseven(abs_nu) ? 1 : -1

    if x >= 0
        return besselk_positive_args(abs_nu, abs_x)
    else
        return throw(DomainError(x, "Complex result returned for real arguments. Complex arguments are currently not supported"))
        #return sg * besselk_positive_args(abs_nu, abs_x) - im * π * besseli_positive_args(abs_nu, abs_x)
    end
end

"""
    besselk_positive_args(x::T) where T <: Union{Float32, Float64}

Modified Bessel function of the second kind of order nu, ``K_{nu}(x)`` valid for postive arguments and orders.
"""
function besselk_positive_args(nu, x::T) where T <: Union{Float32, Float64}
    iszero(x) && return T(Inf)
    isinf(x) && return zero(T)

    # dispatch to avoid uniform expansion when nu = 0 
    iszero(nu) && return besselk0(x)
    
    # pre-compute the uniform asymptotic expansion cutoff:
    debye_cut = besselik_debye_cutoff(nu, x)

    # check if nu is a half-integer:
    (isinteger(nu-1/2) && !debye_cut) && return sphericalbesselk(nu-1/2, x)*SQRT_PID2(T)*sqrt(x)

    # use uniform debye expansion if x or nu is large
    debye_cut && return besselk_large_orders(nu, x)

    # for integer nu use forward recurrence starting with K_0 and K_1
    isinteger(nu) && return besselk_up_recurrence(x, besselk1(x), besselk0(x), 1, nu)[1]

    # for small x and nu > x use power series
    besselk_power_series_cutoff(nu, x) && return besselk_power_series(nu, x)

    # for rest of values use the continued fraction approach
    return besselk_continued_fraction(nu, x)
end
"""
    besselkx(x::T) where T <: Union{Float32, Float64}

Scaled modified Bessel function of the second kind of order nu, ``K_{nu}(x)*e^{x}``.
"""
besselkx(nu::Real, x::Real) = _besselkx(nu, float(x))

_besselkx(nu, x::Float16) = Float16(_besselkx(nu, Float32(x)))

function _besselkx(nu, x::T) where T <: Union{Float32, Float64}
    # dispatch to avoid uniform expansion when nu = 0 
    iszero(nu) && return besselk0x(x)

    # use uniform debye expansion if x or nu is large
    besselik_debye_cutoff(nu, x) && return besselk_large_orders_scaled(nu, x)

    # for integer nu use forward recurrence starting with K_0 and K_1
    isinteger(nu) && return besselk_up_recurrence(x, besselk1x(x), besselk0x(x), 1, nu)[1]

    # for small x and nu > x use power series
    besselk_power_series_cutoff(nu, x) && return besselk_power_series(nu, x) * exp(x)

    # for rest of values use the continued fraction approach
    return besselk_continued_fraction(nu, x) * exp(x)
end

#####
#####  Debye's uniform asymptotic for K_{nu}(x)
#####

# Implements the uniform asymptotic expansion https://dlmf.nist.gov/10.41
# In general this is valid when either x or nu is gets large
# see the file src/U_polynomials.jl for more details
"""
    besselk_large_orders(nu, x::T)

Debey's uniform asymptotic expansion for large order valid when v-> ∞ or x -> ∞
"""
function besselk_large_orders(v, x::T) where T
    S = promote_type(T, Float64)
    x = S(x)
    z = x / v
    zs = hypot(1, z)
    n = zs + log(z) - log1p(zs)
    coef = SQPIO2(S) * sqrt(inv(v)) * exp(-v*n) / sqrt(zs)
    p = inv(zs)
    p2  = v^2/fma(max(v,x), max(v,x), min(v,x)^2)

    return T(coef*Uk_poly_Kn(p, v, p2, T))
end
function besselk_large_orders_scaled(v, x::T) where T
    S = promote_type(T, Float64)
    x = S(x)
    z = x / v
    zs = hypot(1, z)
    n = zs + log(z) - log1p(zs)
    coef = SQPIO2(S) * sqrt(inv(v)) * exp(-v*n + x) / sqrt(zs)
    p = inv(zs)
    p2  = v^2/fma(max(v,x), max(v,x), min(v,x)^2)

    return T(coef*Uk_poly_Kn(p, v, p2, T))
end
besselik_debye_cutoff(nu, x::Float64) = nu > 25.0 || x > 35.0
besselik_debye_cutoff(nu, x::Float32) = nu > 15.0f0 || x > 20.0f0

#####
#####  Continued fraction with Wronskian for K_{nu}(x)
#####

# Use the ratio K_{nu+1}/K_{nu} and I_{nu-1}, I_{nu}
# along with the Wronskian (NIST https://dlmf.nist.gov/10.28.E2) to calculate K_{nu}
# Inu and Inum1 are generated from the power series form where K_{nu_1}/K_{nu}
# is calculated with continued fractions. 
# The continued fraction K_{nu_1}/K_{nu} method is a slightly modified form
# https://github.com/heltonmc/Bessels.jl/issues/17#issuecomment-1195726642 by @cgeoga  
# 
# It is also possible to use continued fraction to calculate inu/inmu1 such as
# inum1 = besseli_power_series(nu-1, x)
# H_inu = steed(nu, x)
# inu = besseli_power_series(nu, x)#inum1 * H_inu
# but it appears to be faster to modify the series to calculate both Inu and Inum1

function besselk_continued_fraction(nu, x)
    inu, inum1 = besseli_power_series_inu_inum1(nu, x)
    H_knu = besselk_ratio_knu_knup1(nu-1, x)
    return 1 / (x * (inum1 + inu / H_knu))
end

# a modified version of the I_{nu} power series to compute both I_{nu} and I_{nu-1}
# use this along with the continued fractions for besselk
function besseli_power_series_inu_inum1(v, x::T) where T
    MaxIter = 3000
    out = zero(T)
    out2 = zero(T)
    x2 = x / 2
    xs = x2^v
    gmx = xs / gamma(v)
    a = gmx / v
    b = gmx / x2
    t2 = x2 * x2
    for i in 0:MaxIter
        out += a
        out2 += b
        abs(a) < eps(T) * abs(out) && break
        a *= inv((v + i + one(T)) * (i + one(T))) * t2
        b *= inv((v + i) * (i + one(T))) * t2
    end
    return out, out2
end

# computes K_{nu+1}/K_{nu} using continued fractions and the modified Lentz method
# generally slow to converge for small x
function besselk_ratio_knu_knup1(v, x::T) where T
    MaxIter = 1000
    (hn, Dn, Cn) = (1e-50, zero(v), 1e-50)

    jf = one(T)
    vv = v * v
    for _ in 1:MaxIter
        an = (vv - ((2*jf - 1)^2) * T(0.25))
        bn = 2 * (x + jf)
        Cn = an / Cn + bn
        Dn = inv(muladd(an, Dn, bn))
        del = Dn * Cn
        hn *= del
        abs(del - 1) < eps(T) && break
        jf += one(T)
    end
    xinv = inv(x)
    return xinv * (v + x + 1/2) + xinv * hn
end

#####
#####  Power series for K_{nu}(x)
#####

# Use power series form of K_v(x) which is accurate for small x (x<2) or when nu > x
# We use the form as described by Equation 3.2 from reference [7].
# This method was originally contributed by @cgeoga https://github.com/cgeoga/BesselK.jl/blob/main/src/besk_ser.jl
# A modified form appears below. See more discussion at https://github.com/heltonmc/Bessels.jl/pull/29
# This is only valid for noninteger orders (nu) and no checks are performed. 
#
"""
    besselk_power_series(nu, x::T) where T <: Float64

Computes ``K_{nu}(x)`` using the power series when nu is not an integer.
In general, this is most accurate for small arguments and when nu > x.
No checks are performed on nu so this is not accurate when nu is an integer.
"""
function besselk_power_series(v, x::T) where T
    MaxIter = 1000
    S = promote_type(T, Float64)
    v, x = S(v), S(x)

    z  = x / 2
    zz = z * z
    logz = log(z)
    xd2_v = exp(v*logz)
    xd2_nv = inv(xd2_v)

    # use the reflection identify to calculate gamma(-v)
    # use relation gamma(v)*v = gamma(v+1) to avoid two gamma calls
    gam_v = gamma(v)
    xp1 = abs(v) + one(S)
    gam_nv = π / (sinpi(xp1) * gam_v * v)
    gam_1mv = -gam_nv * v
    gam_1mnv = gam_v * v

    _t1 = gam_v * xd2_nv * gam_1mv
    _t2 = gam_nv * xd2_v * gam_1mnv
    (xd2_pow, fact_k, out) = (one(S), one(S), zero(S))
    for k in 0:MaxIter
        t1 = xd2_pow * T(0.5)
        tmp = muladd(_t1, gam_1mnv, _t2 * gam_1mv)
        tmp *= inv(gam_1mv * gam_1mnv * fact_k)
        term = t1 * tmp
        out += term
        abs(term / out) < eps(T) && break
        (gam_1mnv, gam_1mv) = (gam_1mnv*(one(S) + v + k), gam_1mv*(one(S) - v + k)) 
        xd2_pow *= zz
        fact_k *= k + one(S)
    end
    return T(out)
end
besselk_power_series_cutoff(nu, x::Float64) = x < 2.0 || nu > 1.6x - 1.0
besselk_power_series_cutoff(nu, x::Float32) = x < 10.0f0 || nu > 1.65f0*x - 8.0f0

