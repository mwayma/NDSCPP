#include "../frame_timing.h"
#include <array>
#include <cassert>
#include <cmath>

int main()
{
    const std::array<uint32_t, 2> buffers{24, 500};
    const auto lead = SharedFrameLeadSeconds(buffers, 27);
    assert(std::abs(lead - (24 * 0.8 / 27)) < 0.000001);
    assert(std::abs(SharedFrameLeadSeconds(std::array<uint32_t, 2>{500, 24}, 27) - lead) < 0.000001);
    assert(SharedFrameLeadSeconds(std::array<uint32_t, 0>{}, 27) == 0.0);
    assert(SharedFrameLeadSeconds(buffers, 0) == 0.0);
    assert(std::abs(SharedFrameLeadSeconds(std::array<uint32_t, 1>{500}, 27) - (500 * 0.8 / 27)) < 0.000001);
    const auto fractional = FrameTimestampWithLead(1'234'567, 0.75);
    assert(fractional.seconds == 1 && fractional.microseconds == 984'567);
    const auto rollover = FrameTimestampWithLead(1'900'000, 0.25);
    assert(rollover.seconds == 2 && rollover.microseconds == 150'000);
    const auto first = FrameTimestampWithLead(1'234'567, lead);
    const auto second = FrameTimestampWithLead(1'234'567, SharedFrameLeadSeconds(buffers, 27));
    assert(first.seconds == second.seconds && first.microseconds == second.microseconds);
}
