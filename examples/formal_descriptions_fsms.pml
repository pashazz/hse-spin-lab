mtype = {
    d0_A, d1_A,
    d0_B, d1_B
}

bool s0_A = false; bool s1_A = false;
bool r0_B = false; bool r1_B = false;
int state_A = 0;
int state_B = 0;

proctype A(chan in, out) {
    do
    ::  (state_A == 0) ->
            out!d0_A
            state_A = 1
    ::  (state_A == 1) ->
            in?d0_B
            state_A = 2
    ::  (state_A == 2) ->
            out!d1_A
            state_A = 3
    ::  (state_A == 3) ->
            in?d1_B
            state_A = 0
    od;
}

proctype B(chan in, out) {
    do
    ::  (state_B == 0) ->
            in?d0_A
            state_B = 1
    ::  (state_B == 1) ->
            out!d0_B
            state_B = 2
    ::  (state_B == 2) ->
            in?d1_A
            state_B = 3
    ::  (state_B == 3) ->
            out!d1_B
            state_B = 0
    od;
}

init {
    chan ch1 = [0] of { mtype };
    chan ch2 = [0] of { mtype };
    atomic {
        run A(ch1, ch2);
        run B(ch2, ch1);
    }
}

ltl f1 {[](s0_A -> ((!s1_A) until (r0_B)))}
ltl f2 {[](s1_A -> ((!s0_A) until (r1_B)))}
ltl f3 {[]<>(1)}
