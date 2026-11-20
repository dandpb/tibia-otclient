#include <gtest/gtest.h>

#include "framework/otml/otmldocument.h"
#include "framework/core/config.h"

#include <sstream>
#include <string>

namespace {

OTMLNodePtr uniqueNode(const std::string_view tag)
{
    const auto& node = OTMLNode::create(tag);
    node->setUnique(true);
    return node;
}

// Mirrors the game_hotkeys layout written by modules/game_hotkeys/hotkeys_manager.lua:
// game_hotkeys -> <host:port/path> -> <character name> -> <key combo> -> fields.
OTMLDocumentPtr buildHotkeysDocument()
{
    const auto& doc = OTMLDocument::create();
    const auto& hotkeys = uniqueNode("game_hotkeys");
    doc->addChild(hotkeys);
    const auto& host = uniqueNode("127.0.0.1:8080/login.php");
    hotkeys->addChild(host);
    const auto& character = uniqueNode("Daniel Guerreiro");
    host->addChild(character);
    const auto& f1 = uniqueNode("F1");
    character->addChild(f1);
    f1->writeAt("autoSend", "false");
    f1->writeAt("itemId", "2160");
    f1->writeAt("useType", "1");
    const auto& combo = uniqueNode("Ctrl+F2");
    character->addChild(combo);
    combo->writeAt("autoSend", "true");
    combo->writeAt("value", "hello");
    return doc;
}

} // namespace

// A settings key containing ':' (host:port/path) must survive save -> restart.
// Before tag quoting, the emitter wrote the tag verbatim and the parser split it
// at the first colon, so hotkeys saved under the host key could never be loaded.
TEST(OTMLTagQuoting, HostPortPathKeyRoundTrips)
{
    const auto& doc = buildHotkeysDocument();
    const auto emitted = doc->emit();

    std::istringstream stream(emitted);
    const auto& parsed = OTMLDocument::parse(stream, "otml_tag_quoting_test");

    const auto& hotkeys = parsed->get("game_hotkeys");
    ASSERT_NE(nullptr, hotkeys);
    const auto& host = hotkeys->get("127.0.0.1:8080/login.php");
    ASSERT_NE(nullptr, host) << "emitted document:\n" << emitted;
    const auto& character = host->get("Daniel Guerreiro");
    ASSERT_NE(nullptr, character);
    const auto& f1 = character->get("F1");
    ASSERT_NE(nullptr, f1);
    EXPECT_EQ("false", f1->valueAt("autoSend"));
    EXPECT_EQ("2160", f1->valueAt("itemId"));
    EXPECT_EQ("1", f1->valueAt("useType"));
    const auto& combo = character->get("Ctrl+F2");
    ASSERT_NE(nullptr, combo);
    EXPECT_EQ("true", combo->valueAt("autoSend"));
    EXPECT_EQ("hello", combo->valueAt("value"));
}

TEST(OTMLTagQuoting, QuotedTagWithColonParses)
{
    const std::string document =
        "\"127.0.0.1:8080/login.php\":\n"
        "  Daniel Guerreiro:\n"
        "    F1:\n"
        "      action: 4\n";
    std::istringstream stream(document);
    const auto& parsed = OTMLDocument::parse(stream, "otml_tag_quoting_test");

    const auto& host = parsed->get("127.0.0.1:8080/login.php");
    ASSERT_NE(nullptr, host);
    EXPECT_TRUE(host->isUnique());
    EXPECT_FALSE(host->hasValue());
    EXPECT_EQ("4", host->get("Daniel Guerreiro")->get("F1")->valueAt("action"));
}

TEST(OTMLTagQuoting, SingleQuotedTagParses)
{
    std::istringstream stream("'host:8080/path':\n  x: 1\n");
    const auto& parsed = OTMLDocument::parse(stream, "otml_tag_quoting_test");
    const auto& host = parsed->get("host:8080/path");
    ASSERT_NE(nullptr, host);
    EXPECT_EQ("1", host->valueAt("x"));
}

TEST(OTMLTagQuoting, TagWithQuotesAndSpacesRoundTrips)
{
    const auto& doc = OTMLDocument::create();
    const auto& node = uniqueNode("key \"with\" quotes: and spaces");
    doc->addChild(node);
    node->writeAt("field", "value");

    const auto emitted = doc->emit();
    std::istringstream stream(emitted);
    const auto& parsed = OTMLDocument::parse(stream, "otml_tag_quoting_test");

    const auto& restored = parsed->get("key \"with\" quotes: and spaces");
    ASSERT_NE(nullptr, restored) << "emitted document:\n" << emitted;
    EXPECT_EQ("value", restored->valueAt("field"));
}

// Unquoted http(s) keys written by older clients must keep parsing.
TEST(OTMLTagQuoting, LegacyUnquotedUrlKeyStillParses)
{
    std::istringstream stream("http://127.0.0.1:8080/login.php:\n  lastWorld: Fortal\n");
    const auto& parsed = OTMLDocument::parse(stream, "otml_tag_quoting_test");
    const auto& url = parsed->get("http://127.0.0.1:8080/login.php");
    ASSERT_NE(nullptr, url);
    EXPECT_EQ("Fortal", url->valueAt("lastWorld"));
}

TEST(OTMLTagQuoting, PlainTagsEmitWithoutQuoting)
{
    const auto& doc = OTMLDocument::create();
    doc->writeAt("window-size", "1277 1360");
    doc->writeAt("locale", "en");
    const auto& bot = uniqueNode("bot");
    doc->addChild(bot);
    bot->writeAt("Grizzle Alyronia_1500", "cavebot_1.3");

    const auto emitted = doc->emit();
    EXPECT_EQ(std::string::npos, emitted.find('"')) << emitted;
    EXPECT_EQ(std::string::npos, emitted.find('\'')) << emitted;

    std::istringstream stream(emitted);
    const auto& parsed = OTMLDocument::parse(stream, "otml_tag_quoting_test");
    EXPECT_EQ("1277 1360", parsed->valueAt("window-size"));
    EXPECT_EQ("en", parsed->valueAt("locale"));
    EXPECT_EQ("cavebot_1.3", parsed->get("bot")->valueAt("Grizzle Alyronia_1500"));
}

// Config files written before tag quoting hold the host key split into
// tag "127.0.0.1" + value "8080/login.php:" with the hotkeys as children.
// Config::load must rejoin them so existing hotkeys are not lost.
TEST(OTMLTagQuoting, RepairsLegacySplitHostTag)
{
    const std::string document =
        "game_hotkeys:\n"
        "  127.0.0.1: 8080/login.php:\n"
        "    Daniel Guerreiro:\n"
        "      F1:\n"
        "        action: 4\n"
        "password: secret:\n"
        "foo: bar\n"
        "  baz: 1\n";
    std::istringstream stream(document);
    const auto& parsed = OTMLDocument::parse(stream, "otml_tag_quoting_test");
    Config::repairLegacySplitTags(parsed);

    const auto& host = parsed->get("game_hotkeys")->get("127.0.0.1:8080/login.php");
    ASSERT_NE(nullptr, host);
    EXPECT_FALSE(host->hasValue());
    EXPECT_EQ("4", host->get("Daniel Guerreiro")->get("F1")->valueAt("action"));

    // scalar leaf whose value ends in ':' must stay a scalar
    EXPECT_EQ("secret:", parsed->valueAt("password"));
    // value not ending in ':' must not be merged even with children
    const auto& foo = parsed->get("foo");
    ASSERT_NE(nullptr, foo);
    EXPECT_EQ("bar", foo->rawValue());
    EXPECT_EQ("1", foo->valueAt("baz"));

    // idempotent
    Config::repairLegacySplitTags(parsed);
    EXPECT_EQ("4", parsed->get("game_hotkeys")->get("127.0.0.1:8080/login.php")->get("Daniel Guerreiro")->get("F1")->valueAt("action"));
}
