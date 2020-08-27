#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt
import math

def main():
    f_S  = 125e6
    f_LO =  25e6

    # relative progression of LO period per sampling point
    delta_phi = 1.0*f_LO/f_S

    # from Matthias Hoffmann's dissertation
    P = 1
    S = int(f_S/f_LO)
    M_min = S/math.gcd(P, S)*1.0 # = LSM(S,P)/P

    # must be a multiple of M_min
    # GEN_SINCOS_TAB_SIZE
    avgfactor = 1
    M = M_min*avgfactor

    # simulation length in ADC samples
    N = 100.

    #k = [k for k in range(0,N)]
    k = np.arange(N)

    err_f = 0
    err_phi = 0
    A = 0.3

    s = A * np.sin(2*np.pi * (f_LO+err_f) * k/f_S + err_phi)

    LUT_sin = A * np.sin(2*np.pi*np.arange(M)*delta_phi)
    LUT_cos = A * np.cos(2*np.pi*np.arange(M)*delta_phi)

    # number of fractional bits for fixed-point representation
    c_data_base = 15
    c_sincos_base = 16
    # in modules/LLRF/FD/hdl/PKG_ADDRESS_SPACE_LLRF_FD.vhd:
    # ----fracbits16

    # scale sin/cos tables for fixed-point representation
    # reverse order: last items become lowest bits which are read as lowest indices
    for x in LUT_cos[::-1]:
        print("to_signed({}, c_sincos_wl),".format(int(x*2**c_sincos_base)))
    for x in LUT_sin[::-1]:
        print("to_signed({}, c_sincos_wl),".format(int(x*2**c_sincos_base)))

    IQ = iq_demod(s, LUT_cos, LUT_sin, avgfactor)
    angle = np.angle(IQ[-1,0]+1j*IQ[-1,1])

    #
    ### cosimtcp part
    #
    import sys
    sys.path.insert(0, '/home/mbuechl/src/cosimtcp/client/python')
    from cosimtcp import cosimtcp

    cosim = cosimtcp('localhost', 23495)

    s_fixed = s*2**c_data_base
    print(s_fixed.astype(int))
    cosim.send_data("data", s_fixed.astype(int))

    cosim.restart()

    # fun first 1 simulation step, no data from buffer used,
    # half clock period, clk starts low
    # three clock periods with reset=1
    init_time = cosim.current_time()
    if (init_time == 0):
        cosim.run_sim(1,  5, "ns", useData=0)
        cosim.run_sim(3, 10, "ns", useData=0)

    # ---------------------------------------------------------
    # run simulation with the buffered data and record result
    # N clock cycles of 10ns
    cosim.run_sim(N, 10, "ns")

    # ---------------------------------------------------------
    # get result from the data buffers
    I_out = cosim.get_data("I")/2**c_sincos_base
    Q_out = cosim.get_data("Q")/2**c_sincos_base
    valid_out = cosim.get_data("valid")

    out = np.array((valid_out, I_out, Q_out))

    out_angle = np.angle(I_out[-1]+1j*Q_out[-1])

    # ---------------------------------------------------------
    # print results
    print("# Model: I")
    print(IQ[-1,0])
    print("# Model: Q")
    print(IQ[-1,1])
    print("# Model: angle")
    print(angle*360/(2*np.pi))
    print("# HDL result: I")
    print(I_out[-1])
    print("# HDL result: Q")
    print(Q_out[-1])
    print("# HDL result: angle")
    print(out_angle*360/(2*np.pi))
    #print("# HDL result: out")
    #print(out)

    plt.plot(IQ[5:,0])
    plt.plot(I_out[valid_out==1])
    plt.legend(['model','HDL'])
    plt.show()

    # ---------------------------------------------------------
    # close simulator
    cosim.quit()

def iq_demod(s, costable, sintable, avgfactor):
    N = s.size
    M = costable.size
    # initial fill of the sliding window
    gen_demod = _demod_ENT_IQ_SLIDE(s, costable, sintable, avgfactor)
    IQ = [next(gen_demod) for i in range(N)]
    IQ_all = np.stack(IQ, axis=0)

    return IQ_all

# pass the whole array of s and the tables of length M
def _demod_ENT_IQ_SLIDE(s, costable, sintable, avgfactor):
    k = 0
    table_offset = 1 # 1 matches ENT_IQ_SLIDE.vhd
    M = costable.size
    IQ_tmp = np.zeros([s.size,2])
    window = np.zeros([M*avgfactor,2])
    # axis 0 represents the columns for I and Q
    # axis 1 represents the rows holding one time step each
    while(True):
        window[1:] = window[:-1]
        IQ_tmp[k] = np.array([s[k]*costable[(k+table_offset)%M], s[k]*sintable[(k+table_offset)%M]])
        window[0] = IQ_tmp[k]
        #yield window.sum(0)/(M/2)/avgfactor # along axis 0 (vertical; all M elements of a column)
        yield window.sum(0) # along axis 0 (vertical; all M elements of a column)
        k = k+1

if __name__ == "__main__":
    main()
