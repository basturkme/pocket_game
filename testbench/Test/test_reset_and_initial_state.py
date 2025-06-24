# test_player_fsm.py (Final Zamanlama Düzeltmeleri)
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

# --- State ve Parametre Tanımları (Verilog ile aynı olmalı) ---
# FSM Durumları
S_IDLE = 0x0
S_MOVE_RIGHT = 0x1
S_MOVE_LEFT = 0x2
S_N_ATK_STARTUP = 0x3
S_N_ATK_ACTIVE = 0x4
S_N_ATK_RECOVERY = 0x5
S_M_ATK_STARTUP = 0x6
S_M_ATK_ACTIVE = 0x7
S_M_ATK_RECOVERY = 0x8
S_HITSTUN = 0x9
S_BLOCKSTUN = 0xA
S_PRE_ATTACK_CHARGE = 0xB
S_BLOCKING_IDLE = 0xC

# Frame Sayıları
PRE_ATTACK_CHARGE_FRAMES = 8
N_ATK_STARTUP_FRAMES = 5
N_ATK_ACTIVE_FRAMES = 2
N_ATK_RECOVERY_FRAMES = 16
M_ATK_STARTUP_FRAMES = 4
M_ATK_ACTIVE_FRAMES = 3
M_ATK_RECOVERY_FRAMES = 15
HITSTUN_DURATION_FRAMES = 10
BLOCKSTUN_DURATION_FRAMES = 8

# Pozisyon ve Hızlar
POSITION_INITIAL_P1 = 100
POSITION_INITIAL_P2 = 500
PLAYER_WIDTH_CONST = 64
MOVE_SPEED_FORWARD = 3
MOVE_SPEED_BACKWARD = 2


# Test için yardımcı sınıf
class PlayerFSM_TB:
    """DUT (player_fsm) ile etkileşimi kolaylaştıran yardımcı sınıf"""

    def __init__(self, dut):
        self.dut = dut

    async def reset(self):
        """Tasarımı resetler"""
        self.dut.reset.value = 1
        self.dut.attack.value = 0
        self.dut.move_left.value = 0
        self.dut.move_right.value = 0
        self.dut.hit_by_opponent.value = 0
        self.dut.confirmed_my_block.value = 0
        await ClockCycles(self.dut.clk_game_logic, 5)
        self.dut.reset.value = 0
        await RisingEdge(self.dut.clk_game_logic)
        self.dut._log.info("Reset tamamlandı.")

    async def wait_cycles(self, cycles=1):
        """Belirtilen sayıda saat döngüsü bekler"""
        await ClockCycles(self.dut.clk_game_logic, cycles)


# --- Test Senaryoları ---

CLOCK_PERIOD_NS = 16666660


@cocotb.test()
async def test_reset_and_initial_state(dut):
    """Oyuncu 1 ve Oyuncu 2 için reset sonrası başlangıç durumlarını test eder"""
    tb = PlayerFSM_TB(dut)
    clock = Clock(dut.clk_game_logic, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())

    dut.main_player.value = 1
    await tb.reset()

    dut._log.info("Test P1 Başlangıç Durumu:")
    assert dut.x_pos_player.value.integer == POSITION_INITIAL_P1
    assert dut.looking_right.value.integer == 1
    assert dut.current_state_reg.value.integer == S_IDLE

    dut.main_player.value = 0
    await tb.reset()

    dut._log.info("Test P2 Başlangıç Durumu:")
    assert dut.x_pos_player.value.integer == POSITION_INITIAL_P2
    assert dut.looking_right.value.integer == 0
    assert dut.current_state_reg.value.integer == S_IDLE


@cocotb.test()
async def test_p1_movement(dut):
    """Oyuncu 1 için hareket mantığını ve FSM gecikmesini doğrular"""
    tb = PlayerFSM_TB(dut)
    clock = Clock(dut.clk_game_logic, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())

    dut.main_player.value = 1
    dut.opponent_x_pos.value = 500
    await tb.reset()

    initial_pos = dut.x_pos_player.value.integer
    dut.move_right.value = 1

    await tb.wait_cycles(2)
    assert dut.current_state_reg.value.integer == S_MOVE_RIGHT

    await tb.wait_cycles(10)

    expected_pos = initial_pos + 10 * MOVE_SPEED_FORWARD
    assert dut.x_pos_player.value.integer == expected_pos, f"P1 ileri hareket hatası: Beklenen={expected_pos}, Gelen={dut.x_pos_player.value.integer}"

    dut.move_right.value = 0
    await tb.wait_cycles(2)
    assert dut.current_state_reg.value.integer == S_IDLE


@cocotb.test()
async def test_neutral_attack_sequence(dut):
    """Normal saldırı dizisinin doğruluğunu test eder"""
    tb = PlayerFSM_TB(dut)
    clock = Clock(dut.clk_game_logic, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())

    dut.main_player.value = 1
    await tb.reset()

    dut.attack.value = 1
    await tb.wait_cycles(2)
    assert dut.current_state_reg.value.integer == S_PRE_ATTACK_CHARGE
    dut.attack.value = 0

    # DÜZELTME: Tam şarj süresi kadar bekle
    await tb.wait_cycles(PRE_ATTACK_CHARGE_FRAMES)

    assert dut.current_state_reg.value.integer == S_N_ATK_STARTUP
    await tb.wait_cycles(N_ATK_STARTUP_FRAMES)

    assert dut.current_state_reg.value.integer == S_N_ATK_ACTIVE
    for _ in range(N_ATK_ACTIVE_FRAMES):
        assert dut.hitbox_active.value.integer == 1
        await tb.wait_cycles(1)

    assert dut.current_state_reg.value.integer == S_N_ATK_RECOVERY
    assert dut.hitbox_active.value.integer == 0
    await tb.wait_cycles(N_ATK_RECOVERY_FRAMES)

    assert dut.current_state_reg.value.integer == S_IDLE


@cocotb.test()
async def test_hit_and_stun(dut):
    """Darbe alma ve HITSTUN durumunu test eder"""
    tb = PlayerFSM_TB(dut)
    clock = Clock(dut.clk_game_logic, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    await tb.reset()

    dut.hit_by_opponent.value = 1
    await tb.wait_cycles(2)
    assert dut.current_state_reg.value.integer == S_HITSTUN
    dut.hit_by_opponent.value = 0

    # DÜZELTME: Tam stun süresi kadar bekle
    await tb.wait_cycles(HITSTUN_DURATION_FRAMES)
    assert dut.current_state_reg.value.integer == S_IDLE


@cocotb.test()
async def test_block_and_stun(dut):
    """Başarılı blok yapma ve BLOCKSTUN durumunu test eder"""
    tb = PlayerFSM_TB(dut)
    clock = Clock(dut.clk_game_logic, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    await tb.reset()

    dut.confirmed_my_block.value = 1
    await tb.wait_cycles(2)
    assert dut.current_state_reg.value.integer == S_BLOCKSTUN
    dut.confirmed_my_block.value = 0

    # DÜZELTME: Tam stun süresi kadar bekle
    await tb.wait_cycles(BLOCKSTUN_DURATION_FRAMES)
    assert dut.current_state_reg.value.integer == S_IDLE


@cocotb.test()
async def test_attack_cancel_by_hit(dut):
    """Saldırı başlangıcında darbe alarak saldırının iptal olmasını test eder"""
    tb = PlayerFSM_TB(dut)
    clock = Clock(dut.clk_game_logic, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    await tb.reset()

    dut.attack.value = 1
    await tb.wait_cycles(2)
    assert dut.current_state_reg.value.integer == S_PRE_ATTACK_CHARGE
    dut.attack.value = 0

    await tb.wait_cycles(PRE_ATTACK_CHARGE_FRAMES // 2)

    dut.hit_by_opponent.value = 1
    await tb.wait_cycles(2)
    assert dut.current_state_reg.value.integer == S_HITSTUN
    dut.hit_by_opponent.value = 0

    await tb.wait_cycles(HITSTUN_DURATION_FRAMES)
    assert dut.current_state_reg.value.integer == S_IDLE
