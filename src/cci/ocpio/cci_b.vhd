--------------------------------------------------------------------------------
-- License: MIT License - Copyright (c) 2016 Mathias Herlev
--------------------------------------------------------------------------------
-- Title		: OCPIO Clock Crossing Interface Slave
-- Type			: Entity
-- Developers	: Mathias Herlev (Creator)(Lead)
--
-- Description	: Master Interface for the OCP clock crossing. Connects to a 
--				  Slave
-- 				: 
-- TODO			:
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
LIBRARY work;
USE work.OCPInterface.all;
USE work.OCPIOCCI_types.all;
USE work.ocp.all;

ENTITY OCPIOCCI_B IS
    GENERIC(IOSize : INTEGER := 1);
    PORT(   clk         : IN    std_logic;
            rst         : IN    std_logic;
            syncIn      : IN    ocp_io_s;
            syncOut     : OUT   ocp_io_m;
            asyncOut    : OUT   asyncIO_B_r;
            asyncIn     : IN    asyncIO_A_r
    );
END ENTITY OCPIOCCI_B;

--------------------------------------------------------------------------------
-- Buffered Architecture
--------------------------------------------------------------------------------
ARCHITECTURE Buffered OF OCPIOCCI_B IS
	----------------------------------------------------------------------------
	-- FSM signals
	----------------------------------------------------------------------------
    TYPE fsm_states_t IS	(IDLE_state, CmdAcceptWait_state, RespWait_state);
    SIGNAL state, state_next    :    fsm_states_t;
	----------------------------------------------------------------------------
	-- Async signals
	----------------------------------------------------------------------------
    SIGNAL req_prev, req, req_next  : std_logic := '0';
    SIGNAL ack, ack_next            : std_logic := '0';

	----------------------------------------------------------------------------
	-- Register signals
	----------------------------------------------------------------------------
    SIGNAL slaveData, slaveData_next  : ocp_io_s;
    SIGNAL loadEnable   : std_logic;

BEGIN

	asyncOut.data <= slaveData WHEN loadEnable = '0' ELSE syncIn;
	asyncOut.ack	<= ack;

	----------------------------------------------------------------------------
	-- FSM
	----------------------------------------------------------------------------
    FSM : PROCESS(state, syncIn, asyncIn, req, req_prev,ack)
    BEGIN
        state_next	<= state;
        loadEnable	<= '0';
		syncOut		<= OCPIOMasterIdle_c;
		ack_next	<= ack;
	
        CASE state IS
            WHEN IDLE_state =>
				--If a new request is available
                IF req = NOT (req_prev) THEN
                    IF (asyncIn.data.MCmd /= OCP_CMD_IDLE) THEN
						--Relay the command to the OCP slave
						syncOut <= asyncIn.data;
						state_next <= CmdAcceptWait_state;
						-- If the command is accepted
						IF syncIn.SCmdAccept = '1' THEN
							state_next <= RespWait_state;
							--And a response is ready
							IF syncIn.SResp /= OCP_RESP_NULL THEN
								state_next <= IDLE_state;
								loadEnable <= '1';
								-- Signal the A side
								ack_next <= NOT (ack);
								syncOut.MRespAccept <= '1';
							END IF;
						END IF;
                    END IF;
                END IF;
			WHEN CmdAcceptWait_state =>
				-- If command has not been accepted, Command+data has not been
				-- Registered in OCP Slave. Continue aserting command.
				syncOut <= asyncIn.data;
				IF syncIn.SCmdAccept = '1' THEN
					state_next <= RespWait_state;
					IF syncIn.SResp /= OCP_RESP_NULL THEN
						state_next <= IDLE_state;
						ack_next <= NOT (ack);
						loadEnable <= '1';
						syncOut.MRespAccept <= '1';					
					END IF;
				END IF;
			WHEN RespWait_state =>	
				IF syncIn.SResp /= OCP_RESP_NULL THEN
					state_next <= IDLE_state;
					ack_next <= NOT (ack);
					loadEnable <= '1';
					syncOut.MRespAccept <= '1';					
				END IF;
			WHEN OTHERS =>
				state_next <= IDLE_state;
		END CASE;
	END PROCESS FSM;


    DataRegMux    : PROCESS(loadEnable, syncIn)
    BEGIN
        slaveData_next <= slaveData;
        IF loadEnable = '1' THEN
            slaveData_next <= syncIn;
        END IF;
    END PROCESS DataRegMux;


    Registers    : PROCESS(clk,rst)
    BEGIN
        IF rst = '1' THEN
            state <= IDLE_state;
			req_prev    <= '0';
            req         <= '0';
            req_next    <= '0';
            ack         <= '0';
            slaveData   <= ocpioslaveidle_c;
        ELSIF rising_edge(clk) THEN
            state       <= state_next;
            req_prev    <= req;
            req         <= req_next;
            req_next    <= asyncIn.req;
            ack         <= ack_next;
            slaveData   <= slaveData_next;
        END IF;
    END PROCESS Registers;

END ARCHITECTURE Buffered;

--------------------------------------------------------------------------------
-- Unbuffered architecture
--------------------------------------------------------------------------------
ARCHITECTURE NonBuffered OF OCPIOCCI_B IS
    TYPE fsm_states_t IS	(Idle_state, CmdAcceptWait_state, RespWait_state,
							ReqWait_state);
    SIGNAL state, state_next    :    fsm_states_t := Idle_state;

    SIGNAL req, req_next	: std_logic := '0';
    SIGNAL ack	: std_logic := '0';


BEGIN
	-- Async Data Signals

    asyncOut.data 		<= syncIn;
    asyncOut.ack 		<= ack;

    FSM : PROCESS(state, syncIn, asyncIn, req)
    BEGIN
		state_next 	<= state;
		syncOut     <= OCPIOMasterIdle_c;

		CASE state IS
			WHEN Idle_state =>
				ack <= '0';
				IF req = '1' THEN
					IF (asyncIn.data.MCmd /= OCP_CMD_IDLE) THEN
						syncOut <= asyncIn.data;
						syncOut.MRespAccept <= '0';
						state_next <= CmdAcceptWait_state;
						IF syncIn.SCmdAccept = '1' THEN
							state_next <= RespWait_state;
							IF syncIn.SResp /= OCP_RESP_NULL THEN
								state_next <= ReqWait_state;
--								ack <= '1';
							END IF;							
						END IF;
					END IF;
				END IF;
			WHEN CmdAcceptWait_state =>
				ack <= '0';
				syncOut <= asyncIn.data;
				syncOut.MRespAccept <= '0';
				IF syncIn.SCmdAccept = '1' THEN
					state_next <= RespWait_state;
					IF syncIn.SResp /= OCP_RESP_NULL THEN
						state_next <= ReqWait_state;
--						ack <= '1';
					END IF;							
				END IF;
			WHEN RespWait_state =>
				ack <= '0';
				IF syncIn.SResp /= OCP_RESP_NULL THEN
					state_next <= ReqWait_state;
					ack <= '1';
				END IF;
			WHEN ReqWait_state =>
				ack <= '1';
				IF req = '0' THEN
					ack <= '0';
					syncOut.MRespAccept <= '1';
					state_next <= Idle_state;				
				END IF;
			WHEN OTHERS =>
				state_next <= IDLE_state;
		END CASE;
	END PROCESS FSM;


	Registers    : PROCESS(clk,rst)
	BEGIN
		IF rst = '1' THEN
			state <= IDLE_state;
			req <= '0';
			req_next <= '0';
		ELSIF rising_edge(clk) THEN
			state       <= state_next;
			req         <= req_next;
			req_next    <= asyncIn.req;
        END IF;
	END PROCESS Registers;

END ARCHITECTURE NonBuffered;
