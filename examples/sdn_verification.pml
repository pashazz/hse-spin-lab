mtype = {
    PostFlow_App, DeleteFlow_App,
    PostFlow_Cont, DeleteFlow_Cont, TIME_TRANSITION,
    PostFlow_Channel1, DeleteFlow_Channel1, LOSS_Channel1,
    ACK_Channel2, LOSS_Channel2,
    ACK_Switch
}

bool send_PF = false; bool send_DF = false;
bool receive_PF = false; bool receive_DF = false;
mtype currGlobalMt;
int flow_entry_cont = 0;
int flow_entry_switch = 0;

proctype App(chan Controller_Out) {
    mtype mt;

    S0: Controller_Out!PostFlow_App
        goto S1;

    S1: if
        ::  (flow_entry_cont <= 2) ->
                Controller_Out!PostFlow_App
                goto S1
        ::  (flow_entry_cont > 1) ->
                Controller_Out!DeleteFlow_App
                goto S1
        ::  (flow_entry_cont == 1) ->
                Controller_Out!DeleteFlow_App
                goto S0
        fi;
}

proctype Controller(chan App_In, Channel2_In, Channel1_Out) {
    mtype mt;
    bool time_s1 = false;
    bool time_s2 = false;

    S0: App_In?mt
        if
        ::  (mt == PostFlow_App) ->
                atomic {
                    currGlobalMt = PostFlow_App
                    flow_entry_cont = flow_entry_cont + 1
                    send_PF = true;
                    send_DF = false;
                }
                goto S1
        ::  (mt == DeleteFlow_App) ->
                atomic {
                    currGlobalMt = DeleteFlow_App
                    flow_entry_cont = flow_entry_cont - 1
                    send_PF = false;
                    send_DF = true;
                }
                goto S3
        fi

    S1: Channel1_Out!PostFlow_Cont;
        goto S2;

    S2: if
        ::  Channel2_In?ACK_Channel2 ->
                atomic {
                    currGlobalMt = ACK_Channel2
                    time_s1 = false
                }
                goto S0
        ::  (!time_s1) ->
                atomic {
                    currGlobalMt = TIME_TRANSITION
                    time_s1 = true
                }
                goto S1
        fi;

    S3: Channel1_Out!DeleteFlow_Cont;
        goto S4;

    S4: if
        ::  Channel2_In?ACK_Channel2 ->
                atomic {
                    currGlobalMt = ACK_Channel2
                    time_s2 = false
                }
                goto S0
        ::  (!time_s2) ->
                atomic {
                    currGlobalMt = TIME_TRANSITION
                    time_s2 = true
                }
                goto S3
        fi;
}

proctype Channel1(chan Controller_In, Switch_Out) {
    mtype mt;
    bool loss_ch1_s1 = false;
    bool loss_ch1_s2 = false;
    
    S0: Controller_In?mt
        if
        ::  (mt == PostFlow_Cont) -> 
            atomic {
                currGlobalMt = PostFlow_Cont
                goto S1
            }
        ::  (mt == DeleteFlow_Cont) -> 
            atomic {
                currGlobalMt = DeleteFlow_Cont
                goto S2
            }
        fi;

    S1: do
        ::  Switch_Out!PostFlow_Channel1
            loss_ch1_s1 = false
            goto S0
        ::  (!loss_ch1_s1) ->
                atomic {
                    currGlobalMt = LOSS_Channel1
                    loss_ch1_s1 = true
                }
                goto S0
        od;

    S2: do
        ::  Switch_Out!DeleteFlow_Channel1
            loss_ch1_s2 = false;
            goto S0
        ::  (!loss_ch1_s2) ->
                atomic {
                    currGlobalMt = LOSS_Channel1
                    loss_ch1_s2 = true
                }
                goto S0
        od;
}

proctype Channel2(chan Switch_In, Controller_Out) {
    mtype mt;
    bool loss_ch2_s1 = false;

    S0: Switch_In?ACK_Switch
        goto S1;

    S1: do
        ::  Controller_Out!ACK_Channel2
            currGlobalMt = ACK_Channel2
            loss_ch2_s1 = false
            goto S0
        ::  (!loss_ch2_s1) ->
                atomic {
                    currGlobalMt = LOSS_Channel2
                    loss_ch2_s1 = true
                }
                goto S0
        od;
}

proctype Switch(chan Channel1_In, Channel2_Out) {
    mtype mt;

    S0: Channel1_In?mt
        if
        ::  (mt == PostFlow_Channel1) ->
            atomic {
                currGlobalMt = PostFlow_Channel1
                flow_entry_switch = flow_entry_switch + 1
                receive_PF = true;
                receive_DF = false;
            }
            goto S1
        ::  (mt == DeleteFlow_Channel1) ->
            atomic {
                currGlobalMt = DeleteFlow_Channel1
                flow_entry_switch = flow_entry_switch - 1
                receive_PF = false;
                receive_DF = true;
            }
            goto S1
        fi;

    S1: Channel2_Out!ACK_Switch;
        goto S0;
}

init {
    chan ch1 = [0] of { mtype }; chan ch2 = [0] of { mtype }; chan ch3 = [0] of { mtype };
    chan ch4 = [0] of { mtype }; chan ch5 = [0] of { mtype };
    //chan ch6 = [0] of { mtype };

    atomic {
        run App(ch1);
        run Controller(ch1, ch5, ch2);
        run Channel1(ch2, ch3);
        run Channel2(ch4, ch5);
        run Switch(ch3, ch4);
    }
}

ltl f1{[](flow_entry_switch >= 0)}
ltl f2{[](flow_entry_cont >= 0)}
ltl f3{[]((flow_entry_cont >= 0) && (flow_entry_switch >= 0))}
ltl f4{[](!timeout)}
