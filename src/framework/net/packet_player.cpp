/*
* Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

#include "packet_player.h"

#include <charconv>
#include <sstream>

#include "framework/core/clock.h"
#include "framework/core/eventdispatcher.h"
#include "framework/net/inputmessage.h"

PacketPlayer::~PacketPlayer()
{
    if (m_event)
        m_event->cancel();
}

PacketPlayer::PacketPlayer(const std::string_view& file)
{
    if (file.empty() || file.find_first_of("/\\:") != std::string_view::npos || !file.ends_with(".cam"))
        throw Exception("Invalid replay filename.");

    const auto path = std::filesystem::path("records") / file;
    std::error_code error;
    const auto bytes = std::filesystem::file_size(path, error);
    std::ifstream input(path, std::ios::binary);
    if (error || bytes > 128 * 1024 * 1024 || !input)
        throw Exception("Unable to open a bounded replay file.");

    constexpr size_t maxPacket = InputMessage::BUFFER_MAXSIZE - 16;
    ticks_t last = 0;
    std::string row;
    while (std::getline(input, row)) {
        if (row.size() > maxPacket * 2 + 32)
            throw Exception("Replay packet exceeds the input buffer.");
        std::istringstream fields(row);
        std::string direction, hex;
        ticks_t at = 0;
        if (!(fields >> direction >> at >> hex) ||
            (direction != "<" && direction != ">") || at < last || at > 24 * 60 * 60 * 1000 ||
            hex.empty() || hex.size() % 2 || hex.size() > maxPacket * 2)
            throw Exception("Invalid replay packet row.");
        fields >> std::ws;
        if (!fields.eof())
            throw Exception("Trailing data in replay packet.");
        last = at;
        if (direction == ">")
            continue; // Outgoing client packets must never be replayed.
        auto packet = std::make_shared<std::vector<uint8_t>>();
        packet->reserve(hex.size() / 2);
        for (size_t i = 0; i < hex.size(); i += 2) {
            unsigned value = 0;
            const auto* end = hex.data() + i + 2;
            const auto result = std::from_chars(end - 2, end, value, 16);
            if (result.ec != std::errc() || result.ptr != end)
                throw Exception("Invalid replay packet hex.");
            packet->push_back(static_cast<uint8_t>(value));
        }
        m_input.emplace_back(at, std::move(packet));
    }
    if (!input.eof() || m_input.empty())
        throw Exception("Replay contains no complete inbound stream.");
}

void PacketPlayer::start(std::function<void(std::shared_ptr<std::vector<uint8_t>>)> recvCallback,
                         std::function<void(std::error_code)> disconnectCallback)
{
    m_start = g_clock.millis();
    m_recvCallback = recvCallback;
    m_disconnectCallback = disconnectCallback;
    schedule(1);
}

void PacketPlayer::schedule(ticks_t delay)
{
    const std::weak_ptr<PacketPlayer> weak = static_self_cast<PacketPlayer>();
    m_event = g_dispatcher.scheduleEvent([weak] {
        if (const auto self = weak.lock())
            self->process();
    }, delay);
}

void PacketPlayer::stop()
{
    if (m_event)
        m_event->cancel();
    m_event = nullptr;
}

void PacketPlayer::onOutputPacket(const OutputMessagePtr& packet)
{
    if (!packet->getBuffer().empty() && packet->getBuffer().front() == 0x14) { // logout
        m_disconnectCallback(asio::error::eof);
        stop();
    }
}

void PacketPlayer::process()
{
    ticks_t nextPacket = 1;
    while (!m_input.empty()) {
        auto& packet = m_input.front();
        nextPacket = (packet.first + m_start) - g_clock.millis();
        if (nextPacket > 1)
            break;
        m_recvCallback(packet.second);
        m_input.pop_front();
    }

    if (!m_input.empty() && nextPacket > 1) {
        schedule(nextPacket);
    } else {
        m_disconnectCallback(asio::error::eof);
        stop();
    }
}
