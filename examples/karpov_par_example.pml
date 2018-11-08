mtype = {
    d0_A, d1_A,
    d0_Sender, d1_Sender, TIME_TRANSITION,
    d0_Channel1, d1_Channel1, LOSS_Channel1,
    d0_Receiver, d1_Receiver, ACK_Receiver,
    ACK_Channel2, LOSS_Channel2,
}

bool send_d0 = false; bool send_d1 = false;
bool receive_d0 = false; bool receive_d1 = false;
mtype currGlobalMt;

proctype A(chan Sender_Out) {
    mtype mt;

    S0: Sender_Out!d0_A;
        goto S1

    S1: Sender_Out!d1_A;
        goto S2

    S2: Sender_Out!d0_A;
        goto S1

}

proctype Sender(chan A_In, Channel2_In, Channel1_Out) {
    mtype mt;
    bool time_s2 = false;
    bool time_s5 = false;

    S0: A_In?d0_A ->
            atomic {
                send_d0 = true;
                send_d1 = false;
                currGlobalMt = d0_A;
            }
        goto S1;

    S1: Channel1_Out!d0_Sender;
        goto S2;

    S2: if
        ::  Channel2_In?ACK_Channel2 ->
                currGlobalMt = ACK_Channel2
                time_s2 = false
                goto S3
        ::  (!time_s2) ->
                currGlobalMt = TIME_TRANSITION
                time_s2 = true
                goto S1
        fi;

    S3: A_In?d1_A ->
            atomic {
                send_d0 = false;
                send_d1 = true;
                currGlobalMt = d1_A;
            }
        goto S4;

    S4: Channel1_Out!d1_Sender;
        goto S5;

    S5: if
        ::  Channel2_In?ACK_Channel2 -> 
                time_s5 = false
                currGlobalMt = ACK_Channel2;
                goto S0
        ::  (!time_s5) ->
                currGlobalMt = TIME_TRANSITION
                time_s5 = true
                goto S4
        fi;
}

proctype Channel1(chan Sender_In, Receiver_Out) {
    mtype mt;
    bool loss_ch1_s1 = false;
    bool loss_ch1_s2 = false;
    
    S0: Sender_In?mt
        currGlobalMt = mt;
        if
        ::  (mt == d0_Sender) -> goto S1
        ::  (mt == d1_Sender) -> goto S2
        fi;

    S1: do
        ::  Receiver_Out!d0_Channel1;
            loss_ch1_s1 = false
            goto S0;
        ::  (!loss_ch1_s1) ->
                currGlobalMt = LOSS_Channel1
                loss_ch1_s1 = true
                goto S0
        od;

    S2: do
        ::  Receiver_Out!d1_Channel1
            loss_ch1_s2 = false;
            goto S0
        ::  (!loss_ch1_s2) ->
                currGlobalMt = LOSS_Channel1
                loss_ch1_s2 = true
                goto S0
        od;
}

proctype Channel2(chan Receiver_In, Sender_Out) {
    mtype mt;
    bool loss_ch2_s1 = false;

    S0: Receiver_In?ACK_Receiver
        currGlobalMt = ACK_Receiver;
        goto S1;

    S1: do
        ::  Sender_Out!ACK_Channel2
            loss_ch2_s1 = false
            goto S0
        ::  (!loss_ch2_s1) ->
                currGlobalMt = LOSS_Channel2
                loss_ch2_s1 = true
                goto S0
        od;
}

proctype Receiver(chan Channel1_In, B_Out, Channel2_Out) {
    mtype mt;

    S0: Channel1_In?mt
        currGlobalMt = mt;
        if
        ::  (mt == d0_Channel1) -> goto S1
        ::  (mt == d1_Channel1) -> goto S5
        fi;

    S1: B_Out!d0_Receiver;
        goto S2;

    S2: Channel2_Out!ACK_Receiver;
        goto S3

    S3: Channel1_In?mt
        currGlobalMt = mt
        if
        ::  (mt == d0_Channel1) -> goto S2
        ::  (mt == d1_Channel1) -> goto S4
        fi;

    S4: B_Out!d1_Receiver;
        goto S5;

    S5: Channel2_Out!ACK_Receiver;
        goto S0
}

proctype B(chan Receiver_In) {
    mtype mt;

    S0: Receiver_In?d0_Receiver ->
            atomic {
                receive_d0 = true;
                receive_d1 = false;
                currGlobalMt = d0_Receiver;
            }
        goto S1;

    S1: Receiver_In?d1_Receiver ->
            atomic {
                receive_d0 = false;
                receive_d1 = true;
                currGlobalMt = d0_Receiver;
            }
        goto S2;

    S2: Receiver_In?d0_Receiver ->
        atomic {
            receive_d0 = true;
            receive_d1 = false;
            currGlobalMt = d0_Receiver;
        }
    goto S1;
}

init {
    chan ch1 = [0] of { mtype }; chan ch2 = [0] of { mtype }; chan ch3 = [0] of { mtype };
    chan ch4 = [0] of { mtype }; chan ch5 = [0] of { mtype }; chan ch6 = [0] of { mtype };

    atomic {
        run A(ch1);
        run Sender(ch1, ch6, ch2);
        run Channel1(ch2, ch3);
        run Channel2(ch5, ch6);
        run Receiver(ch3, ch4, ch5);
        run B(ch4);
    }
}

ltl f1 {[](send_d0 -> ((!send_d1) until (receive_d0)))}
ltl f2 {[](send_d1 -> ((!send_d0) until receive_d1))}
ltl f3 {[](receive_d0 -> ((!receive_d1) until send_d0))}
ltl f4 {[](receive_d1 -> ((!receive_d0) until send_d1))}
ltl f5 {[]((send_d0 -> <>(send_d1)) && (send_d1 -> <>(send_d0)))}
ltl f6 {[](!timeout)}
