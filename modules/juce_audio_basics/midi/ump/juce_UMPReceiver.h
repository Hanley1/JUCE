/*
  ==============================================================================

   This file is part of the JUCE library.
   Copyright (c) 2020 - Raw Material Software Limited

   JUCE is an open source library subject to commercial or open-source
   licensing.

   The code included in this file is provided under the terms of the ISC license
   http://www.isc.org/downloads/software-support-policy/isc-license. Permission
   To use, copy, modify, and/or distribute this software for any purpose with or
   without fee is hereby granted provided that the above copyright notice and
   this permission notice appear in all copies.

   JUCE IS PROVIDED "AS IS" WITHOUT ANY WARRANTY, AND ALL WARRANTIES, WHETHER
   EXPRESSED OR IMPLIED, INCLUDING MERCHANTABILITY AND FITNESS FOR PURPOSE, ARE
   DISCLAIMED.

  ==============================================================================
*/

<<<<<<< HEAD:modules/juce_audio_basics/midi/ump/juce_UMPSysEx7.cpp
=======
#ifndef DOXYGEN

>>>>>>> 53b04877c6ebc7ef3cb42e84cb11a48e0cf809b5:modules/juce_audio_basics/midi/ump/juce_UMPReceiver.h
namespace juce
{
namespace universal_midi_packets
{

<<<<<<< HEAD:modules/juce_audio_basics/midi/ump/juce_UMPSysEx7.cpp
uint32_t SysEx7::getNumPacketsRequiredForDataSize (uint32_t size)
{
    constexpr auto denom = 6;
    return (size / denom) + ((size % denom) != 0);
}

SysEx7::PacketBytes SysEx7::getDataBytes (const PacketX2& packet)
{
    const auto numBytes = Utils::getChannel (packet[0]);
    constexpr uint8_t maxBytes = 6;
    jassert (numBytes <= maxBytes);

    return
    {
        { packet.getU8<2>(),
          packet.getU8<3>(),
          packet.getU8<4>(),
          packet.getU8<5>(),
          packet.getU8<6>(),
          packet.getU8<7>() },
        jmin (numBytes, maxBytes)
    };
}

}
}
=======
/**
    A base class for classes which receive Universal MIDI Packets from an input.

    @tags{Audio}
*/
struct Receiver
{
    virtual ~Receiver() noexcept = default;

    /** This will be called each time a new packet is ready for processing. */
    virtual void packetReceived (const View& packet, double time) = 0;
};

}
}

#endif
>>>>>>> 53b04877c6ebc7ef3cb42e84cb11a48e0cf809b5:modules/juce_audio_basics/midi/ump/juce_UMPReceiver.h
