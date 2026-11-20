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

#include "otmldocument.h"
#include "otmlemitter.h"

namespace {

// Tags are emitted verbatim and the parser splits unquoted lines at the first
// ':', so any tag containing ':' (e.g. host:port/path settings keys) or other
// syntax characters must be quoted to survive a save/load round trip.
bool tagNeedsQuoting(const std::string_view tag)
{
    if (tag.empty())
        return false;

    const auto isSpace = [](const char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; };

    // Leading characters the parser treats as syntax (list item, alias, comment,
    // quoted tag) rather than as part of the tag.
    const char front = tag.front();
    if (front == '-' || front == '&' || front == '#' || front == '"' || front == '\'' || isSpace(front))
        return true;

    // Unquoted tags are split at the first ':' and trimmed on both ends.
    if (tag.find(':') != std::string_view::npos || isSpace(tag.back()))
        return true;

    return false;
}

void emitTag(std::ostream& out, const std::string_view tag)
{
    if (!tagNeedsQuoting(tag)) {
        out << tag;
        return;
    }
    out << '"';
    for (const char c : tag) {
        if (c == '"' || c == '\\')
            out << '\\';
        out << c;
    }
    out << '"';
}

} // namespace

std::string OTMLEmitter::emitNode(const OTMLNodePtr& node, const int currentDepth)
{
    std::stringstream ss;

    // emit nodes
    if (currentDepth >= 0) {
        // fill spaces for current depth
        for (int i = 0; i < currentDepth; ++i)
            ss << "  ";

        // emit node tag
        if (node->hasTag()) {
            emitTag(ss, node->tag());

            // add ':' to if the node is unique or has value
            if (node->hasValue() || node->isUnique() || node->isNull())
                ss << ":";
        } else
            ss << "-";

        // emit node value
        if (node->isNull())
            ss << " ~";
        else if (node->hasValue()) {
            ss << " ";

            const auto& value = node->value();

            // emit multiline values
            if (value.find('\n') != std::string::npos) {
                if (value[value.length() - 1] == '\n' && value[value.length() - 2] == '\n')
                    ss << "|+";
                else if (value[value.length() - 1] == '\n')
                    ss << "|";
                else
                    ss << "|-";

                //  multilines
                for (std::size_t pos = 0; pos < value.length(); ++pos) {
                    ss << "\n";

                    // fill spaces for multiline depth
                    for (int i = 0; i < currentDepth + 1; ++i)
                        ss << "  ";

                    // fill until a new line
                    while (pos < value.length()) {
                        if (value[pos] == '\n')
                            break;
                        ss << value[++pos];
                    }
                }
                // emit inline values
            } else
                ss << value;
        }
    }

    // emit children
    for (size_t i = 0; i < node->size(); ++i) {
        if (currentDepth >= 0 || i != 0)
            ss << "\n";
        ss << emitNode(node->atIndex(static_cast<int>(i)), currentDepth + 1);
    }

    return ss.str();
}
