#pragma once

#include <algorithm>
#include <cstdint>
#include <span>

// Every feature on one canvas must use the same playback lead. Otherwise a
// larger receiver buffer causes that strip to play the shared animation late.
inline double SharedFrameLeadSeconds(std::span<const uint32_t> capacities, uint16_t fps)
{
    if (capacities.empty() || fps == 0) return 0.0;
    // Keep half the smallest queue free for clock skew and delivery jitter.
    constexpr double fillRatio = 0.50;
    return (*std::min_element(capacities.begin(), capacities.end()) * fillRatio) / fps;
}

struct FrameTimestamp
{
    uint64_t seconds;
    uint64_t microseconds;
};

inline FrameTimestamp FrameTimestampWithLead(int64_t nowMicros, double leadSeconds)
{
    // Add before splitting so fractional lead time is retained across rollover.
    const auto playbackMicros = nowMicros + static_cast<int64_t>(leadSeconds * 1'000'000.0);
    return { static_cast<uint64_t>(playbackMicros / 1'000'000),
             static_cast<uint64_t>(playbackMicros % 1'000'000) };
}
