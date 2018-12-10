mtype = {
  PostFlow_App, DeleteFlow_App,
  PostFlow_Cont, DeleteFlow_Cont,
  PostFlow_Channel1, DeleteFlow_Channel1,
  LOSS_Channel1,
  ACK_Switch,
  ACK_Channel2, LOSS_Channel2
}
int flow_entry_cont = 0;
int flow_entry_switch = 0;

proctype Application(chan ControllerOut) {
S0:ControllerOut!PostFlow_App;
  atomic {
    flow_entry_cont = 1;
    printf("flow_entry_cont = %d\n", flow_entry_cont);
  }
  goto S1;
S1:do
     :: flow_entry_cont <= 2 ->
        atomic {
          ControllerOut!PostFlow_App;
          flow_entry_cont = flow_entry_cont + 1;
          printf("flow_entry_cont = %d\n", flow_entry_cont);
        }
     :: flow_entry_cont > 1 ->
        atomic {
          ControllerOut!DeleteFlow_App;
          flow_entry_cont = flow_entry_cont - 1;
          printf("flow_entry_cont = %d\n", flow_entry_cont);
        }
     :: flow_entry_cont == 1 ->
        atomic{
          ControllerOut!DeleteFlow_App;
          flow_entry_cont = 0;
          printf("flow_entry_cont = %d\n", flow_entry_cont);
        }
        goto S0
  od;


}

proctype Controller(chan ApplicationIn, Channel1Out, Channel2In) {
  int ackId = 0;
  int inputAckId = 0;
S0:if
     :: ApplicationIn?PostFlow_App ->
        goto S1;
     :: ApplicationIn?DeleteFlow_App ->
        goto S3;
  fi;

S1:Channel1Out!PostFlow_Cont,ackId;
  goto S2;

S2:do
     :: goto S1;
     :: Channel2In?ACK_Channel2,inputAckId;
        atomic {
          if
            :: (inputAckId == ackId) ->
               ackId = ackId + 1;
               goto S0;
            :: (inputAckId < ackId) ->
               goto S2;
          fi;
        }
  od;
S3:Channel1Out!DeleteFlow_Cont,ackId;
  goto S4;
S4:do
     :: goto S3
     :: Channel2In?ACK_Channel2, inputAckId;
        atomic {
          if
            :: (inputAckId  == ackId) ->
               ackId = ackId + 1;
               goto S0;
            :: (inputAckId < ackId) ->
               goto S3;
          fi;
        }
  od;
}

proctype Switch (chan Channel1In, Channel2Out)
{
  int ackId = -1;
  int currentAckId = -1;
  mtype mt;
S0:Channel1In?mt,currentAckId;
  if
    :: (currentAckId <= ackId) ->
         Channel2Out!ACK_Switch,currentAckId;
         goto S0;
    :: (currentAckId > ackId) ->
       atomic {
         ackId =currentAckId;
         if
           :: (mt == DeleteFlow_Channel1) ->
              atomic {
                flow_entry_switch = flow_entry_switch - 1;
                printf("flow_entry_switch = %d\n", flow_entry_switch)
              }
           :: (mt == PostFlow_Channel1) ->
              atomic {
                flow_entry_switch = flow_entry_switch + 1;
                printf("flow_entry_switch = %d\n", flow_entry_switch)
              }
         fi
       }
       goto S1;
  fi;
S1:Channel2Out!ACK_Switch,ackId;
  goto S0;
}

proctype Channel1(chan ControllerIn, SwitchOut)
{
  mtype mt;
  int ackId;
S0:ControllerIn?mt,ackId;
  if
    :: (mt == PostFlow_Cont) -> goto S1
    :: (mt == DeleteFlow_Cont) -> goto S2
  fi;
S1:do
     :: goto S0
     :: SwitchOut!PostFlow_Channel1,ackId;
        goto S0
  od;
S2:do
     :: goto S0
     :: SwitchOut!DeleteFlow_Channel1,ackId;
        goto S0
  od;
}

proctype Channel2(chan SwitchIn, ControllerOut)
{
  int ackId;
S0:SwitchIn?ACK_Switch,ackId;
  goto S1;
S1:do
     :: goto S0;
     :: ControllerOut!ACK_Channel2,ackId;
        goto S0;
  od;

}


init {
  chan ch1 = [0] of { mtype };
  chan ch2 = [0] of { mtype, int };
  chan ch3 = [0] of {mtype, int};
  chan ch4 = [0] of {mtype, int};
  chan ch5 = [0] of {mtype, int};
  atomic {
    run Application(ch1);
    run Controller(ch1, ch2, ch5);
    run Channel1(ch2, ch3);
    run Channel2(ch4, ch5);
    run Switch(ch3, ch4);
  }
}

ltl f1 {[](flow_entry_cont >= 0)}
ltl f2 {[](flow_entry_switch >= 0)}
ltl f3 {[](!timeout)}
