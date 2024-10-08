library ieee;
use ieee.std_logic_1164.all;

entity SimpleProcessor is
	port(
			clock			: in std_logic;
			reset			: in std_logic;
			MEM_read		: out std_logic;
			MEM_write	: out std_logic;
			MFC			: in std_logic;
			MEM_address	: out std_logic_vector(15 downto 0);
			Data_to_Mem	: out std_logic_vector(15 downto 0);
			Data_from_Mem : in std_logic_vector(15 downto 0);
			-- for ModelSim debugging only
			debug_PC	: out std_logic_vector(15 downto 0);
			debug_IR	: out std_logic_vector(15 downto 0);
			debug_state : out std_logic_vector(2 downto 0);
			debug_r1	: out std_logic_vector(15 downto 0);
			debug_r2	: out std_logic_vector(15 downto 0);
			debug_r3	: out std_logic_vector(15 downto 0);
			debug_r4	: out std_logic_vector(15 downto 0);
			debug_r5	: out std_logic_vector(15 downto 0);
			debug_r6	: out std_logic_vector(15 downto 0);
			debug_r7	: out std_logic_vector(15 downto 0);
			debug_RA	: out std_logic_vector(15 downto 0);
			debug_RB	: out std_logic_vector(15 downto 0);
			debug_Extension : out std_logic_vector(15 downto 0);
			debug_RZ	: out std_logic_vector(15 downto 0);
			debug_RY	: out std_logic_vector(15 downto 0)
	);
end SimpleProcessor;

architecture implementation of SimpleProcessor is
	component RegisterFile8by16Bit is
		port(
			clock, reset, RF_write			:in std_logic;
			AddressA, AddressB, AddressC	:in std_logic_vector(2 downto 0);
			InputC								:in std_logic_vector(15 downto 0);
			OutputA, OutputB   				:out std_logic_vector(15 downto 0);
			-- for debugging only
			debug_r1	: out std_logic_vector(15 downto 0);
			debug_r2	: out std_logic_vector(15 downto 0);
			debug_r3	: out std_logic_vector(15 downto 0);
			debug_r4	: out std_logic_vector(15 downto 0);
			debug_r5	: out std_logic_vector(15 downto 0);
			debug_r6	: out std_logic_vector(15 downto 0);
			debug_r7	: out std_logic_vector(15 downto 0)
		);
	end component;
	component ALU is
		port(
			ALU_op 			: in std_logic_vector(1 downto 0);
			A, B 				: in std_logic_vector(15 downto 0);
			A_inv, B_inv 	: in std_logic;
			C_in				: in std_logic;
			ALU_out 			: out std_logic_vector(15 downto 0);
			N, C, V, Z 		: out std_logic
		);
	end component;
	component Immediate is
		port(
			IR: in std_logic_vector(15 downto 0);
			PC: in std_logic_vector(15 downto 0);
			extend: in std_logic_vector(2 downto 0);
			extension: out std_logic_vector(15 downto 0)
		);
	end component;
	component ControlUnit is
		port(
			clock	: in  std_logic;
			reset	: in  std_logic;
			status: in  std_logic_vector(15 downto 0);
			MFC	: in  std_logic;
			IR		: in  std_logic_vector(15 downto 0);
			RF_write	: out std_logic;
			C_select	: out std_logic_vector(1 downto 0);
			B_select : out std_logic;
			Y_select	: out std_logic_vector(1 downto 0);
			ALU_op	: out std_logic_vector(1 downto 0);
			A_inv		: out std_logic;
			B_inv		: out std_logic;
			C_in		: out std_logic;
			MEM_read	: out std_logic;
			MEM_write: out std_logic;
			MA_select: out std_logic;
			IR_enable: out std_logic;
			PC_select: out std_logic_vector(1 downto 0);
			PC_enable: out std_logic;
			INC_select: out std_logic;
			extend	: out std_logic_vector(2 downto 0);
			Status_enable : out std_logic;
			-- for ModelSim debugging only
			debug_state	: out std_logic_vector(2 downto 0)
		);
	end component;
	component Adder16Bit is
		port(
			X, Y 	: in std_logic_vector(15 downto 0);
			C_in 	: in std_logic;
			S 		: out std_logic_vector(15 downto 0);
			C_out_14, C_out_15 : out std_logic
		);
	end component;
	component Reg16Bit is
		port(
			clock   : in std_logic;
			reset   : in std_logic;
			enable  : in std_logic;
			D		  : in std_logic_vector(15 downto 0);
			Q		  : out std_logic_vector(15 downto 0)
		);
	end component;
	component Mux2Input16Bit is
		port(
			s : in  std_logic;
			input0, input1 : in  std_logic_vector(15 downto 0);
			result : out std_logic_vector(15 downto 0));
	end component;
	component Mux4Input16Bit is
		port(
			s : in  std_logic_vector(1 downto 0);
			input0, input1, input2, input3 : in  std_logic_vector(15 downto 0);
			result : out std_logic_vector(15 downto 0));
	end component;
	component Mux4Input3Bit is
		port(
			s : in  std_logic_vector(1 downto 0);
			input0, input1, input2, input3 : in  std_logic_vector(2 downto 0);
			result : out std_logic_vector(2 downto 0));
	end component;

	-- component data
	signal Data_RFOutA,Data_RFOutB: std_logic_vector(15 downto 0);
	signal Data_MuxC 					: std_logic_vector(2 downto 0);
	signal Data_RA, Data_RB			: std_logic_vector(15 downto 0);
	signal Data_MuxB, Data_ALU		: std_logic_vector(15 downto 0);
	signal Data_RZ						: std_logic_vector(15 downto 0);
	signal Data_MuxY, Data_RY		: std_logic_vector(15 downto 0);
	signal Data_IR, Data_Extension: std_logic_vector(15 downto 0);
	signal Data_MuxInc, Data_Adder: std_logic_vector(15 downto 0);
	signal Data_MuxPC, Data_PC		: std_logic_vector(15 downto 0);
	signal Data_PC_temp				: std_logic_vector(15 downto 0);
	signal Data_Status				: std_logic_vector(15 downto 0);
	
	-- control signals
	signal	RF_write	: std_logic;
	signal 	C_select	: std_logic_vector(1 downto 0);
	signal	B_select : std_logic;
	signal 	Y_select	: std_logic_vector(1 downto 0);
	signal	ALU_op	: std_logic_vector(1 downto 0);
	signal	A_inv		: std_logic;
	signal	B_inv		: std_logic;
	signal	C_in		: std_logic;
	signal   N, C, V, Z : std_logic;
	signal	MA_select: std_logic;
	signal	IR_enable: std_logic;
	signal	PC_select: std_logic_vector(1 downto 0);
	signal	PC_enable: std_logic;
	signal	INC_select: std_logic;
	signal	extend	: std_logic_vector(2 downto 0);
	signal	Status_enable : std_logic;
	-- Student Code:  add your interal signals below
	signal 	IR_out : std_logic_vector(15 downto 0);
	signal 	imm_out : std_logic_vector(15 downto 0);
	signal 	PC_out	: std_logic_vector(15 downto 0);
	signal 	MuxINC_out	: std_logic_vector(15 downto 0);
	signal 	PCAdder_out	: std_logic_vector(15 downto 0);
	signal	RA_out : std_logic_vector(15 downto 0);
	signal 	MuxPC_out : std_logic_vector(15 downto 0);
	signal 	RZ_out : std_logic_vector(15 downto 0);
	signal 	PC_temp_out : std_logic_vector(15 downto 0);
	signal	RB_out : std_logic_vector(15 downto 0);
	signal 	MuxY_out : std_logic_vector(15 downto 0);
	
	--ALU signals
	signal 	ALU_inputB: std_logic_vector(15 downto 0);
	signal 	ALU_inputA: std_logic_vector(15 downto 0);
	signal 	ALU_out	: std_logic_vector(15 downto 0);
	
	--reg file internal signals
	signal 	inputC : std_logic_vector(15 downto 0);
	signal 	addressC : std_logic_vector(2 downto 0);
	
	
begin

	-- for debugging only
	debug_PC <= PC_out;
	debug_IR <= IR_out;
	debug_RA <= RA_out;
	debug_RB <= RB_out;
	debug_Extension <= imm_out;
	debug_RZ <= RZ_out;
	debug_RY <= inputC;
	
	


	--  Connect processor components below
	IR : Reg16Bit port map (clock=>clock,D=>Data_from_Mem,enable=>IR_enable,reset=>reset,Q=>IR_out);
	
	ImmExten : Immediate port map (IR=>IR_out,extend=>extend,extension=>imm_out,PC=>PC_out);
	
	MuxINC : Mux2Input16Bit port map (input0=>"0000000000000001",input1=>imm_out,s=>INC_select,result=>MuxINC_out);
	
	PCAdder : Adder16Bit port map (X=>MuxINC_out,Y=>PC_out,S=>PCAdder_out,C_in=>'0');
	
	MuxPC	: Mux4Input16Bit port map (input0=>RA_out,input1=>PCAdder_out,input2=>imm_out,input3=>"0000000000000000",s=>PC_select,result=>MuxPC_out);
	
	PC	: Reg16Bit port map (clock=>clock,enable=>PC_enable,D=>MuxPC_out,Q=>PC_out,reset=>reset);
	
	MuxMA : Mux2Input16Bit port map (input1=>PC_out,input0=>RZ_out,s=>MA_select,result=>MEM_address);
	
	PC_temp : Reg16Bit port map (clock=>clock,D=>PC_out,Q=>PC_temp_out,reset=>reset,enable=>'1');
	
	RY : Reg16Bit port map (clock=>clock,D=>MuxY_out,Q=>inputC,reset=>reset,enable=>'1');
	
	MuxY : Mux4Input16Bit port map (result=>MuxY_out,input0=>RZ_out,input1=>Data_from_Mem,input2=>PC_temp_out,input3=>"0000000000000000",s=>Y_select);
	
	RZ : Reg16Bit port map (clock=>clock,D=>ALU_out,Q=>RZ_out,reset=>reset,enable=>'1');
	
	RM : Reg16Bit port map (clock=>clock,D=>RB_out,Q=>Data_to_Mem,reset=>reset,enable=>'1');
	
	MuxB : Mux2Input16Bit port map (s=>B_select,input1=>imm_out,input0=>RB_out,result=>ALU_inputB);
	
	ALU16Bit : ALU port map (B=>ALU_inputB,A=>RA_out,A_inv=>A_inv,B_inv=>B_inv,C_in=>C_in,ALU_op=>ALU_op,N=>N,C=>C,V=>V,Z=>Z,ALU_out=>ALU_out);
	
	RA : Reg16Bit port map (clock=>clock,D=>Data_RFOutA,Q=>RA_out,reset=>reset,enable=>'1');
	
	RB : Reg16Bit port map (clock=>clock,D=>Data_RFOutB,Q=>RB_out,reset=>reset,enable=>'1');
	
	RegFile : RegisterFile8by16Bit port map(clock=>clock,reset=>reset,RF_write=>RF_write,
									AddressA=>IR_out(15 downto 13),AddressB=>IR_out(12 downto 10),AddressC=>addressC,
									InputC=>inputC,OutputA=>Data_RFOutA,OutputB=>Data_RFOutB,
									debug_r1=>debug_r1,debug_r2=>debug_r2,debug_r3=>debug_r3
									,debug_r4=>debug_r4,debug_r5=>debug_r5,debug_r6=>debug_r6,debug_r7=>debug_r7);
	
	MuxC : Mux4Input3Bit port map (s=>C_select,input0=>IR_out(12 downto 10),input1=>IR_out(9 downto 7),input2=>"111",input3=>"000",result=>addressC);
	
	StatusReg : Reg16Bit port map (reset=>reset,clock=>clock,enable=>Status_enable,D(0)=>Z,D(1)=>V,D(2)=>C,D(3)=>N,D(15 downto 4)=>"000000000000",Q=>Data_Status);
		
	Control_Unit : ControlUnit port map (clock=>clock,reset=>reset,status=>Data_Status,
													MFC=>MFC,IR=>IR_out,RF_write=>RF_write,C_select=>C_select,
													B_select=>B_select,Y_select=>Y_select,ALU_op=>ALU_op,A_inv=>A_inv,
													B_inv=>B_inv,C_in=>C_in,MEM_read=>MEM_read,MEM_write=>MEM_write,
													MA_select=>MA_select,IR_enable=>IR_enable,PC_select=>PC_select,
													PC_enable=>PC_enable,INC_select=>INC_select,extend=>extend,
													Status_enable=>Status_enable,debug_state=>debug_state);
													
	
	
end implementation;