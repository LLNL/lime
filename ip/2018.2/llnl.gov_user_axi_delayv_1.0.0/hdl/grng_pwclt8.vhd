library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity grng_pwclt8 is port(
  iClk : in std_logic;
  iCE : in std_logic := '1';
  iLoadEn : in std_logic := '0';
  iLoadData : in std_logic := '0';
  oRes : out std_logic_vector(17-1 downto 0)
); end entity;

architecture RTL of grng_pwclt8 is
    signal iURNG : std_logic_vector(119-1 downto 0);
    --Bernoulli
    -- bernoulli_fp, fb=26, frac_width=25, exp_width=6
    --   exp_src_width=54
    signal bernoulli_fp_out : boolean;
    signal bernoulli_fp_thresh : unsigned(31-1 downto 0);
    signal bernoulli_fp_urng : std_logic_vector(79-1 downto 0);
    signal bernoulli_fp_cx_exp_urng : std_logic_vector(54-1 downto 0);
    signal bernoulli_fp_c0_frac_thresh, bernoulli_fp_c0_frac_rand : unsigned(25-1 downto 0);
    signal bernoulli_fp_cx_exp_rand, bernoulli_fp_c0_exp_thresh: unsigned(6-1 downto 0);
    signal bernoulli_fp_c1_exp_greater, bernoulli_fp_c1_exp_equal, bernoulli_fp_c1_frac_greater : boolean;
    signal lmz_branch_1, lmz_branch_1_sig : unsigned(6-1 downto 0);
    signal lmz_branch_hit_1, lmz_branch_hit_1_sig : boolean;
    signal lmz_branch_2, lmz_branch_2_sig : unsigned(6-1 downto 0);
    signal lmz_branch_hit_2, lmz_branch_hit_2_sig : boolean;
    signal lmz_branch_3, lmz_branch_3_sig : unsigned(6-1 downto 0);
    signal lmz_branch_hit_3, lmz_branch_hit_3_sig : boolean;
    signal lmz_branch_4, lmz_branch_4_sig : unsigned(6-1 downto 0);
    signal lmz_branch_hit_4, lmz_branch_hit_4_sig : boolean;
    signal lmz_branch_5, lmz_branch_5_sig : unsigned(6-1 downto 0);
    signal lmz_branch_hit_5, lmz_branch_hit_5_sig : boolean;
    signal lmz_branch_6, lmz_branch_6_sig : unsigned(6-1 downto 0);
    signal lmz_branch_hit_6, lmz_branch_hit_6_sig : boolean;
    signal lmz_branch_7, lmz_branch_7_sig : unsigned(6-1 downto 0);
    signal lmz_branch_hit_7, lmz_branch_hit_7_sig : boolean;
    signal bernoulli_fp_c0_exp_rand : unsigned(6-1 downto 0);
    signal bernoulli_fp_c0_exp_rand_d1 : unsigned(6-1 downto 0);
    signal bernoulli_fp_c0_exp_rand_d2 : unsigned(6-1 downto 0);
    --Alias table
    signal alias_table_urng : std_logic_vector(86-1 downto 0);
    signal alias_table_out, c0_alias_index : unsigned(7-1 downto 0);
    attribute rom_style : string;
    type alias_rom_t is array(0 to 128-1) of unsigned(38-1 downto 0);
    signal alias_rom : alias_rom_t := (
        "00000000000001111011110000000100010010", -- i=0, alt=18, thresh=0.996223, actual=0.0499982, err=-6.34814e-012
        "00000000110011000001100001001100001100", -- i=1, alt=12, thresh=0.900344, actual=0.0992142, err=-4.25333e-011
        "00000000010101111001100000010100001101", -- i=2, alt=13, thresh=0.957229, actual=0.096904, err=-3.40242e-011
        "00000000100000010000100010011100010001", -- i=3, alt=17, thresh=0.936995, actual=0.0931726, err=2.32787e-011
        "00000000100000010000100010011100000100", -- i=4, alt=4, thresh=NaN, actual=0.0881888, err=1.00038e-008
        "00000000101001100000001001001110010001", -- i=5, alt=17, thresh=0.918941, actual=0.0821707, err=5.26025e-011
        "00000000100010000011001111111110000100", -- i=6, alt=4, thresh=0.933495, actual=0.0753701, err=5.64949e-011
        "00000001001100110101000000111110001101", -- i=7, alt=13, thresh=0.849945, actual=0.068055, err=4.43661e-011
        "00000001100011001001110001100010000100", -- i=8, alt=4, thresh=0.806342, actual=0.0604922, err=-3.9297e-012
        "00000001100101001010110001000110010001", -- i=9, alt=17, thresh=0.802406, actual=0.0529319, err=-5.45532e-011
        "00000001001011000001111110011010000000", -- i=10, alt=0, thresh=0.853455, actual=0.0455947, err=-2.62078e-011
        "00000000010110110000011011100000001100", -- i=11, alt=12, thresh=0.955553, actual=0.0386625, err=5.44859e-012
        "00000000000100100110110011111010000000", -- i=12, alt=0, thresh=0.991003, actual=0.0322733, err=1.66696e-011
        "00000000000100111011110011001010000100", -- i=13, alt=4, thresh=0.990363, actual=0.0265202, err=-6.99619e-012
        "00000001101100101010110110010010001101", -- i=14, alt=13, thresh=0.787755, actual=0.021453, err=-6.8076e-012
        "00000000000001000101111011101100010010", -- i=15, alt=18, thresh=0.997866, actual=0.0170835, err=3.85316e-011
        "00000001100001111100100000101000001111", -- i=16, alt=15, thresh=0.8087, actual=0.013392, err=-4.5273e-011
        "00000000001001101000111100010000000100", -- i=17, alt=4, thresh=0.981172, actual=0.0103346, err=-3.06494e-011
        "00000000000000100000100011010010000100", -- i=18, alt=4, thresh=0.999007, actual=0.00785092, err=1.12211e-012
        "00000001111111001110011111011110000000", -- i=19, alt=0, thresh=0.751511, actual=0.00587118, err=-3.11606e-011
        "00000011100100101111001101010100000010", -- i=20, alt=2, thresh=0.553247, actual=0.00432224, err=1.50046e-011
        "00000101100101011011111000001010000101", -- i=21, alt=5, thresh=0.400942, actual=0.00313236, err=-1.3286e-011
        "00000111011011000110010000111010000110", -- i=22, alt=6, thresh=0.286037, actual=0.00223467, err=-1.09052e-011
        "00001001100100100101111001101000000001", -- i=23, alt=1, thresh=0.200883, actual=0.0015694, err=-5.85427e-012
        "00001011100011100100101001100010000111", -- i=24, alt=7, thresh=0.138881, actual=0.001085, err=-9.34479e-012
        "00001101111100110110011010011000010000", -- i=25, alt=16, thresh=0.094519, actual=0.00073843, err=-5.33513e-012
        "00001111111100100111101101101010001000", -- i=26, alt=8, thresh=0.0633251, actual=0.000494727, err=-1.02101e-014
        "00010010101001110111001011100110001110", -- i=27, alt=14, thresh=0.0417649, actual=0.000326288, err=2.4127e-012
        "00010101000011101110110100110000001001", -- i=28, alt=9, thresh=0.027116, actual=0.000211844, err=-3.99496e-013
        "00010111100100000011010101010100001010", -- i=29, alt=10, thresh=0.0173308, actual=0.000135397, err=7.31167e-013
        "00011010011010101100011000100000000011", -- i=30, alt=3, thresh=0.0109041, actual=8.51885e-005, err=4.75888e-013
        "00011101000101011000111001100000001011", -- i=31, alt=11, thresh=0.00675371, actual=5.27633e-005, err=-3.56257e-013
        "00011111110010001000011010000010001100", -- i=32, alt=12, thresh=0.00411787, actual=3.21708e-005, err=3.21304e-013
        "00100010111100000010100010111000001111", -- i=33, alt=15, thresh=0.00247162, actual=1.93095e-005, err=-5.163e-014
        "00100110000001001010101001100010000100", -- i=34, alt=4, thresh=0.00146039, actual=1.14093e-005, err=4.91542e-015
        "00101001000010101001001100111110001101", -- i=35, alt=13, thresh=0.00084945, actual=6.63632e-006, err=5.32423e-014
        "00101100000001111110111101000110000000", -- i=36, alt=0, thresh=0.000486389, actual=3.79992e-006, err=2.3514e-014
        "00101111100000100001001100000000000010", -- i=37, alt=2, thresh=0.000274164, actual=2.1419e-006, err=-2.74521e-014
        "00110011000000111101011101010110000101", -- i=38, alt=5, thresh=0.00015213, actual=1.18852e-006, err=-4.32568e-015
        "00110110100011011101000111100110000110", -- i=39, alt=6, thresh=8.30996e-005, actual=6.49216e-007, err=-2.27432e-015
        "00111010001001001001111000111010000001", -- i=40, alt=1, thresh=4.46851e-005, actual=3.49102e-007, err=2.14132e-015
        "00111101110011001001101011110000000111", -- i=41, alt=7, thresh=2.3654e-005, actual=1.84797e-007, err=-1.09373e-015
        "01000001100010011001110100010110001000", -- i=42, alt=8, thresh=1.23261e-005, actual=9.6298e-008, err=-7.64191e-016
        "01000101010111101010100110000000001110", -- i=43, alt=14, thresh=6.32308e-006, actual=4.9399e-008, err=-2.02039e-016
        "01001001010011011011101100001100001001", -- i=44, alt=9, thresh=3.19308e-006, actual=2.49459e-008, err=9.50786e-017
        "01001101010101111001101111100110001010", -- i=45, alt=10, thresh=1.58734e-006, actual=1.24011e-008, err=-1.43824e-017
        "01010001011110111101010111100000000011", -- i=46, alt=3, thresh=7.768e-007, actual=6.06875e-009, err=5.28564e-017
        "01010101101110001011101110100100001011", -- i=47, alt=11, thresh=3.74221e-007, actual=2.9236e-009, err=-1.43742e-017
        "01011010000010111000100110011100001100", -- i=48, alt=12, thresh=1.77471e-007, actual=1.38649e-009, err=1.15157e-017
        "01011110011100001001101100111010000100", -- i=49, alt=4, thresh=8.28524e-008, actual=6.47284e-010, err=6.34471e-018
        "01100010111000111010111011101000001101", -- i=50, alt=13, thresh=3.8077e-008, actual=2.97477e-010, err=-3.33216e-018
        "01100111011000000011000110101110000000", -- i=51, alt=0, thresh=1.72266e-008, actual=1.34583e-010, err=1.72722e-018
        "01101011111000011000101110110110000010", -- i=52, alt=2, thresh=7.67216e-009, actual=5.99388e-011, err=-6.90065e-019
        "01110000110001101100101110111110000101", -- i=53, alt=5, thresh=3.36368e-009, actual=2.62788e-011, err=9.73484e-020
        "01110101110000111100100011010110000110", -- i=54, alt=6, thresh=1.45175e-009, actual=1.13418e-011, err=-2.65092e-021
        "01111010101100111010000100000100000001", -- i=55, alt=1, thresh=6.16806e-010, actual=4.8188e-012, err=4.27139e-021
        "01111111100100010110010101001010000111", -- i=56, alt=7, thresh=2.57979e-010, actual=2.01546e-012, err=2.69505e-020
        "10000100101100110110000000000110001000", -- i=57, alt=8, thresh=1.06219e-010, actual=8.29836e-013, err=-2.19303e-021
        "10001010000101010011101101011000001001", -- i=58, alt=9, thresh=4.30523e-011, actual=3.36346e-013, err=-7.41794e-022
        "10001111010001110011000100010100001010", -- i=59, alt=10, thresh=1.71782e-011, actual=1.34205e-013, err=-6.12052e-022
        "10010100100101001101001110110000000011", -- i=60, alt=3, thresh=6.74722e-012, actual=5.27126e-014, err=-2.72598e-022
        "10011010010000110011111001000100001011", -- i=61, alt=11, thresh=2.60904e-012, actual=2.03831e-014, err=-1.86457e-022
        "10011111101000011111010000110000001100", -- i=62, alt=12, thresh=9.93024e-013, actual=7.758e-015, err=-7.68847e-023
        "10100101011100111110111111101010000100", -- i=63, alt=4, thresh=3.72161e-013, actual=2.90751e-015, err=-3.25876e-024
        "10101011001010111110100000010010000000", -- i=64, alt=0, thresh=1.37234e-013, actual=1.07214e-015, err=3.59351e-024
        "10110000111110110101110010001010000010", -- i=65, alt=2, thresh=4.98667e-014, actual=3.89584e-016, err=-1.22317e-024
        "10110110111111010011110101101000000101", -- i=66, alt=5, thresh=1.78019e-014, actual=1.39077e-016, err=-3.65681e-025
        "10111100111011011000011000000010000110", -- i=67, alt=6, thresh=6.28135e-015, actual=4.90731e-017, err=2.35194e-025
        "11000011001000000111011101010000000001", -- i=68, alt=1, thresh=2.16413e-015, actual=1.69072e-017, err=1.33703e-025
        "11001001010001101011100110010010000111", -- i=69, alt=7, thresh=7.46484e-016, actual=5.83191e-018, err=-4.93447e-026
        "11001111100111000011100100111010001000", -- i=70, alt=8, thresh=2.4368e-016, actual=1.90375e-018, err=2.15454e-026
        "11010101100100011001011101010010001001", -- i=71, alt=9, thresh=8.9252e-017, actual=6.97281e-019, err=1.7606e-027
        "11011011111111111111111111111110001010", -- i=72, alt=10, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000011", -- i=73, alt=3, thresh=0, actual=0, err=0
        "11011011111111111111111111111110001011", -- i=74, alt=11, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000100", -- i=75, alt=4, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000000", -- i=76, alt=0, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000010", -- i=77, alt=2, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000101", -- i=78, alt=5, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000110", -- i=79, alt=6, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000001", -- i=80, alt=1, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000111", -- i=81, alt=7, thresh=0, actual=0, err=0
        "11011011111111111111111111111110001000", -- i=82, alt=8, thresh=0, actual=0, err=0
        "11011011111111111111111111111110001001", -- i=83, alt=9, thresh=0, actual=0, err=0
        "11011011111111111111111111111110001010", -- i=84, alt=10, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000011", -- i=85, alt=3, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000100", -- i=86, alt=4, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000000", -- i=87, alt=0, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000010", -- i=88, alt=2, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000101", -- i=89, alt=5, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000110", -- i=90, alt=6, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000001", -- i=91, alt=1, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000111", -- i=92, alt=7, thresh=0, actual=0, err=0
        "11011011111111111111111111111110001000", -- i=93, alt=8, thresh=0, actual=0, err=0
        "11011011111111111111111111111110001001", -- i=94, alt=9, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000011", -- i=95, alt=3, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000100", -- i=96, alt=4, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000010", -- i=97, alt=2, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000101", -- i=98, alt=5, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000110", -- i=99, alt=6, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000001", -- i=100, alt=1, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000111", -- i=101, alt=7, thresh=0, actual=0, err=0
        "11011011111111111111111111111110001000", -- i=102, alt=8, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000011", -- i=103, alt=3, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000100", -- i=104, alt=4, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000010", -- i=105, alt=2, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000101", -- i=106, alt=5, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000110", -- i=107, alt=6, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000001", -- i=108, alt=1, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000111", -- i=109, alt=7, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000011", -- i=110, alt=3, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000100", -- i=111, alt=4, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000010", -- i=112, alt=2, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000101", -- i=113, alt=5, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000110", -- i=114, alt=6, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000001", -- i=115, alt=1, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000011", -- i=116, alt=3, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000100", -- i=117, alt=4, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000010", -- i=118, alt=2, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000101", -- i=119, alt=5, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000001", -- i=120, alt=1, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000011", -- i=121, alt=3, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000100", -- i=122, alt=4, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000010", -- i=123, alt=2, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000001", -- i=124, alt=1, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000011", -- i=125, alt=3, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000010", -- i=126, alt=2, thresh=0, actual=0, err=0
        "11011011111111111111111111111110000001" -- i=127, alt=1, thresh=0, actual=0, err=0
    );
    attribute rom_style of alias_rom:signal is "distributed";
    signal c1_alias_thresh_bits : unsigned(38-1 downto 0);
    signal c1_alias_thresh_bits_d1 : unsigned(38-1 downto 0);
    signal c1_alias_index : unsigned(7-1 downto 0);
    signal c1_alias_index_d1 : unsigned(7-1 downto 0);
    signal c2_alias_alt : unsigned(7-1 downto 0);
    signal c2_alias_alt_d1 : unsigned(7-1 downto 0);
    signal c2_alias_index : unsigned(7-1 downto 0);
    signal c2_alias_index_d1 : unsigned(7-1 downto 0);
    signal cltfx_out : std_logic_vector(10-1 downto 0);
    signal cltfx_urng : std_logic_vector(32-1 downto 0);
    signal cltfx_sum_4_1 : signed(8-1 downto 0);
    signal cltfx_sum_4_2 : signed(8-1 downto 0);
    signal cltfx_sum_4_3 : signed(8-1 downto 0);
    signal cltfx_sum_4_4 : signed(8-1 downto 0);
    signal cltfx_sum_2_1 : signed(9-1 downto 0);
    signal cltfx_sum_2_2 : signed(9-1 downto 0);
    signal cltfx_sum_1_1 : signed(10-1 downto 0);
    --Mixture PDF
    signal mixture_pdf_urng : std_logic_vector(119-1 downto 0);
    signal c0_mixture_sign_flag : std_logic;
    signal c1_mixture_sindex : signed(8-1 downto 0);
    signal mixture_pdf_out : std_logic_vector(17-1 downto 0);
begin
--Render glue
    urng : entity work.urng_w119 generic map(W=>119) port map(clk=>iClk,ce=>iCE,load_en=>iLoadEn,load_data=>iLoadData,rng=>iURNG);
    mixture_pdf_urng<=iURNG;
    oRes<=std_logic_vector(mixture_pdf_out);
--Implementation
    --Bernoulli
    bernoulli_fp_cx_exp_urng <= bernoulli_fp_urng(79-1 downto 25);
    bernoulli_fp_c0_exp_thresh <= unsigned(bernoulli_fp_thresh(31-1 downto 25));
    bernoulli_fp_c0_frac_rand <= unsigned(bernoulli_fp_urng(25-1 downto 0));
    bernoulli_fp_c0_frac_thresh <= unsigned(bernoulli_fp_thresh(25-1 downto 0));
    bernoulli_fp_out <= bernoulli_fp_c1_exp_greater or (bernoulli_fp_c1_exp_equal and bernoulli_fp_c1_frac_greater);

    lmz_branch_1_sig <=  to_unsigned(0,6) when bernoulli_fp_cx_exp_urng(0) = '1' else
             to_unsigned(1,6) when bernoulli_fp_cx_exp_urng(1) = '1' else
             to_unsigned(2,6) when bernoulli_fp_cx_exp_urng(2) = '1' else
             to_unsigned(3,6) when bernoulli_fp_cx_exp_urng(3) = '1' else
             to_unsigned(4,6) when bernoulli_fp_cx_exp_urng(4) = '1' else
             to_unsigned(5,6) when bernoulli_fp_cx_exp_urng(5) = '1' else
             to_unsigned(6,6) when bernoulli_fp_cx_exp_urng(6) = '1' else
             to_unsigned(7,6);
    lmz_branch_hit_1_sig <= bernoulli_fp_cx_exp_urng(7 downto 0) /= std_logic_vector(to_unsigned(0,8));

    lmz_branch_2_sig <=  to_unsigned(8,6) when bernoulli_fp_cx_exp_urng(8) = '1' else
             to_unsigned(9,6) when bernoulli_fp_cx_exp_urng(9) = '1' else
             to_unsigned(10,6) when bernoulli_fp_cx_exp_urng(10) = '1' else
             to_unsigned(11,6) when bernoulli_fp_cx_exp_urng(11) = '1' else
             to_unsigned(12,6) when bernoulli_fp_cx_exp_urng(12) = '1' else
             to_unsigned(13,6) when bernoulli_fp_cx_exp_urng(13) = '1' else
             to_unsigned(14,6) when bernoulli_fp_cx_exp_urng(14) = '1' else
             to_unsigned(15,6);
    lmz_branch_hit_2_sig <= bernoulli_fp_cx_exp_urng(15 downto 8) /= std_logic_vector(to_unsigned(0,8));

    lmz_branch_3_sig <=  to_unsigned(16,6) when bernoulli_fp_cx_exp_urng(16) = '1' else
             to_unsigned(17,6) when bernoulli_fp_cx_exp_urng(17) = '1' else
             to_unsigned(18,6) when bernoulli_fp_cx_exp_urng(18) = '1' else
             to_unsigned(19,6) when bernoulli_fp_cx_exp_urng(19) = '1' else
             to_unsigned(20,6) when bernoulli_fp_cx_exp_urng(20) = '1' else
             to_unsigned(21,6) when bernoulli_fp_cx_exp_urng(21) = '1' else
             to_unsigned(22,6) when bernoulli_fp_cx_exp_urng(22) = '1' else
             to_unsigned(23,6);
    lmz_branch_hit_3_sig <= bernoulli_fp_cx_exp_urng(23 downto 16) /= std_logic_vector(to_unsigned(0,8));

    lmz_branch_4_sig <=  to_unsigned(24,6) when bernoulli_fp_cx_exp_urng(24) = '1' else
             to_unsigned(25,6) when bernoulli_fp_cx_exp_urng(25) = '1' else
             to_unsigned(26,6) when bernoulli_fp_cx_exp_urng(26) = '1' else
             to_unsigned(27,6) when bernoulli_fp_cx_exp_urng(27) = '1' else
             to_unsigned(28,6) when bernoulli_fp_cx_exp_urng(28) = '1' else
             to_unsigned(29,6) when bernoulli_fp_cx_exp_urng(29) = '1' else
             to_unsigned(30,6) when bernoulli_fp_cx_exp_urng(30) = '1' else
             to_unsigned(31,6);
    lmz_branch_hit_4_sig <= bernoulli_fp_cx_exp_urng(31 downto 24) /= std_logic_vector(to_unsigned(0,8));

    lmz_branch_5_sig <=  to_unsigned(32,6) when bernoulli_fp_cx_exp_urng(32) = '1' else
             to_unsigned(33,6) when bernoulli_fp_cx_exp_urng(33) = '1' else
             to_unsigned(34,6) when bernoulli_fp_cx_exp_urng(34) = '1' else
             to_unsigned(35,6) when bernoulli_fp_cx_exp_urng(35) = '1' else
             to_unsigned(36,6) when bernoulli_fp_cx_exp_urng(36) = '1' else
             to_unsigned(37,6) when bernoulli_fp_cx_exp_urng(37) = '1' else
             to_unsigned(38,6) when bernoulli_fp_cx_exp_urng(38) = '1' else
             to_unsigned(39,6);
    lmz_branch_hit_5_sig <= bernoulli_fp_cx_exp_urng(39 downto 32) /= std_logic_vector(to_unsigned(0,8));

    lmz_branch_6_sig <=  to_unsigned(40,6) when bernoulli_fp_cx_exp_urng(40) = '1' else
             to_unsigned(41,6) when bernoulli_fp_cx_exp_urng(41) = '1' else
             to_unsigned(42,6) when bernoulli_fp_cx_exp_urng(42) = '1' else
             to_unsigned(43,6) when bernoulli_fp_cx_exp_urng(43) = '1' else
             to_unsigned(44,6) when bernoulli_fp_cx_exp_urng(44) = '1' else
             to_unsigned(45,6) when bernoulli_fp_cx_exp_urng(45) = '1' else
             to_unsigned(46,6) when bernoulli_fp_cx_exp_urng(46) = '1' else
             to_unsigned(47,6);
    lmz_branch_hit_6_sig <= bernoulli_fp_cx_exp_urng(47 downto 40) /= std_logic_vector(to_unsigned(0,8));

    lmz_branch_7_sig <=  to_unsigned(48,6) when bernoulli_fp_cx_exp_urng(48) = '1' else
             to_unsigned(49,6) when bernoulli_fp_cx_exp_urng(49) = '1' else
             to_unsigned(50,6) when bernoulli_fp_cx_exp_urng(50) = '1' else
             to_unsigned(51,6) when bernoulli_fp_cx_exp_urng(51) = '1' else
             to_unsigned(52,6) when bernoulli_fp_cx_exp_urng(52) = '1' else
             to_unsigned(53,6);
    lmz_branch_hit_7_sig <= bernoulli_fp_cx_exp_urng(53 downto 48) /= std_logic_vector(to_unsigned(0,6));
    bernoulli_fp_cx_exp_rand <=
        lmz_branch_1 when lmz_branch_hit_1 else
        lmz_branch_2 when lmz_branch_hit_2 else
        lmz_branch_3 when lmz_branch_hit_3 else
        lmz_branch_4 when lmz_branch_hit_4 else
        lmz_branch_5 when lmz_branch_hit_5 else
        lmz_branch_6 when lmz_branch_hit_6 else
        lmz_branch_7 when lmz_branch_hit_7 else
        to_unsigned(54,6);

    bernoulli_fp_c0_exp_rand <= bernoulli_fp_c0_exp_rand_d2;
    --Alias table
    c0_alias_index <= unsigned(alias_table_urng(7-1 downto 0));
    bernoulli_fp_urng <= alias_table_urng(86-1 downto 7);
    bernoulli_fp_thresh <= c1_alias_thresh_bits(38-1 downto 7);

    c1_alias_thresh_bits <= c1_alias_thresh_bits_d1;

    c1_alias_index <= c1_alias_index_d1;

    c2_alias_alt <= c2_alias_alt_d1;

    c2_alias_index <= c2_alias_index_d1;

    cltfx_sum_4_1 <= signed(cltfx_urng(8-1 downto 0));
    cltfx_sum_4_2 <= signed(cltfx_urng(16-1 downto 8));
    cltfx_sum_4_3 <= signed(cltfx_urng(24-1 downto 16));
    cltfx_sum_4_4 <= signed(cltfx_urng(32-1 downto 24));
    cltfx_out<= std_logic_vector(cltfx_sum_1_1);
    --Alias table
    alias_table_urng <= mixture_pdf_urng(86-1 downto 0);
    cltfx_urng <= mixture_pdf_urng(118-1 downto 86);
    c0_mixture_sign_flag <= mixture_pdf_urng(118);
process(iClk) begin if(rising_edge(iClk)) then if(iCE='1') then
    --Bernoulli

    lmz_branch_1 <= lmz_branch_1_sig;
    lmz_branch_hit_1 <= lmz_branch_hit_1_sig;
    lmz_branch_2 <= lmz_branch_2_sig;
    lmz_branch_hit_2 <= lmz_branch_hit_2_sig;
    lmz_branch_3 <= lmz_branch_3_sig;
    lmz_branch_hit_3 <= lmz_branch_hit_3_sig;
    lmz_branch_4 <= lmz_branch_4_sig;
    lmz_branch_hit_4 <= lmz_branch_hit_4_sig;
    lmz_branch_5 <= lmz_branch_5_sig;
    lmz_branch_hit_5 <= lmz_branch_hit_5_sig;
    lmz_branch_6 <= lmz_branch_6_sig;
    lmz_branch_hit_6 <= lmz_branch_hit_6_sig;
    lmz_branch_7 <= lmz_branch_7_sig;
    lmz_branch_hit_7 <= lmz_branch_hit_7_sig;

    bernoulli_fp_c0_exp_rand_d1 <= bernoulli_fp_cx_exp_rand;
    bernoulli_fp_c0_exp_rand_d2 <= bernoulli_fp_c0_exp_rand_d1;
    bernoulli_fp_c1_exp_greater <= bernoulli_fp_c0_exp_rand > bernoulli_fp_c0_exp_thresh;
    bernoulli_fp_c1_exp_equal <= bernoulli_fp_c0_exp_rand = bernoulli_fp_c0_exp_thresh;
    bernoulli_fp_c1_frac_greater <= bernoulli_fp_c0_frac_rand > bernoulli_fp_c0_frac_thresh;
    --Alias table

    c1_alias_thresh_bits_d1 <= alias_rom(to_integer(c0_alias_index));

    c1_alias_index_d1 <= c0_alias_index;

    c2_alias_alt_d1 <= c1_alias_thresh_bits(7-1 downto 0);

    c2_alias_index_d1 <= c1_alias_index;
    if bernoulli_fp_out then
        alias_table_out <= c2_alias_index;
    else
        alias_table_out <= c2_alias_alt;
    end if;

    cltfx_sum_2_1 <= resize(cltfx_sum_4_2,9) - resize(cltfx_sum_4_1,9);
    cltfx_sum_2_2 <= resize(cltfx_sum_4_4,9) - resize(cltfx_sum_4_3,9);
    cltfx_sum_1_1 <= resize(cltfx_sum_2_2,10) - resize(cltfx_sum_2_1,10);
    --Alias table
    if c0_mixture_sign_flag='1' then
        c1_mixture_sindex <= signed(resize(unsigned(alias_table_out),8));
    else
        c1_mixture_sindex <= -signed(resize(unsigned(alias_table_out),8));
    end if;
    mixture_pdf_out <= std_logic_vector(resize(signed(cltfx_out),17) + ((resize(c1_mixture_sindex,17) sll 8)));
end if; end if; end process;
end RTL;
