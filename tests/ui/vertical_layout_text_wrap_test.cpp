#include <gtest/gtest.h>

#include "framework/core/eventdispatcher.h"
#include "framework/luaengine/luainterface.h"
#include "framework/ui/uianchorlayout.h"
#include "framework/ui/uiboxlayout.h"
#include "framework/ui/uihorizontallayout.h"
#include "framework/ui/uilayout.h"
#include "framework/ui/uiverticallayout.h"
#include "framework/ui/uiwidget.h"

namespace {

class UILayoutConvergenceTest : public ::testing::Test
{
protected:
    void SetUp() override {
        g_lua.init();
        g_lua.registerClass<UIWidget>();
        g_lua.registerClass<UILayout>();
        g_lua.registerClass<UIBoxLayout, UILayout>();
        g_lua.registerClass<UIVerticalLayout, UIBoxLayout>();
        g_lua.registerClass<UIHorizontalLayout, UIBoxLayout>();
        g_lua.registerClass<UIAnchorLayout, UILayout>();
        g_dispatcher.init();
    }

    void TearDown() override {
        g_dispatcher.shutdown();
        g_lua.terminate();
    }
};

} // namespace

// Regression test: an unattached/zero-width container whose vertical layout
// collapses a text-wrap + text-auto-resize child (such as inactive game_bot tabs
// containing BotLabel) must converge cleanly inside EventDispatcher::poll()
// instead of oscillating forever between layout width <= 0 and textBoxSize.width().
TEST_F(UILayoutConvergenceTest, WrappedAutoResizeChildInZeroWidthVerticalLayoutConverges)
{
    auto panel = std::make_shared<UIWidget>();
    panel->setRect(Rect(0, 0, 0, 0));

    auto content = std::make_shared<UIWidget>();
    content->setId("content");
    panel->addChild(content);

    auto anchorLayout = std::make_shared<UIAnchorLayout>(panel);
    panel->setLayout(anchorLayout);
    anchorLayout->fill(content, "parent");
    content->setMarginLeft(1);
    content->setMarginRight(8);
    content->setMarginBottom(5);

    auto verticalLayout = std::make_shared<UIVerticalLayout>(content);
    content->setLayout(verticalLayout);

    auto label = std::make_shared<UIWidget>();
    label->setId("botLabel");
    label->setHeight_px(15);
    label->setPadding(2); // ensures textBoxSize > 0 even without loaded fonts
    label->setTextAlign(Fw::AlignCenter);
    label->setTextAutoResize(true);
    label->setTextWrap(true);
    content->addChild(label);
    label->setText("Mana training");

    // Must terminate immediately without an infinite executeDeferEvents loop.
    g_dispatcher.poll();
    g_dispatcher.poll();

    EXPECT_EQ(0, label->getWidth());

    // Once the parent container receives a positive width (tab becomes active),
    // the child must expand cleanly to the container's inner width.
    panel->setRect(Rect(0, 0, 200, 300));
    g_dispatcher.poll();
    g_dispatcher.poll();

    EXPECT_EQ(191, label->getWidth());

    label->destroy();
    content->destroy();
    panel->destroy();
}

TEST_F(UILayoutConvergenceTest, WrappedAutoResizeChildWithOpposingAnchorsConvergesAtZeroWidth)
{
    auto container = std::make_shared<UIWidget>();
    container->setRect(Rect(0, 0, 0, 0));

    auto anchorLayout = std::make_shared<UIAnchorLayout>(container);
    container->setLayout(anchorLayout);

    auto label = std::make_shared<UIWidget>();
    label->setPadding(2);
    label->setTextAutoResize(true);
    label->setTextWrap(true);
    container->addChild(label);
    anchorLayout->addAnchor(label, Fw::AnchorLeft, "parent", Fw::AnchorLeft);
    anchorLayout->addAnchor(label, Fw::AnchorRight, "parent", Fw::AnchorRight);
    anchorLayout->addAnchor(label, Fw::AnchorTop, "parent", Fw::AnchorTop);
    label->setText("Anchored wrap");

    g_dispatcher.poll();
    g_dispatcher.poll();

    EXPECT_EQ(0, label->getWidth());

    label->destroy();
    container->destroy();
}

TEST_F(UILayoutConvergenceTest, SingleAnchoredWrappedAutoResizeChildKeepsIntrinsicWidth)
{
    auto container = std::make_shared<UIWidget>();
    container->setRect(Rect(0, 0, 200, 200));

    auto anchorLayout = std::make_shared<UIAnchorLayout>(container);
    container->setLayout(anchorLayout);

    auto label = std::make_shared<UIWidget>();
    label->setPadding(3);
    label->setTextAutoResize(true);
    label->setTextWrap(true);
    container->addChild(label);
    anchorLayout->addAnchor(label, Fw::AnchorLeft, "parent", Fw::AnchorLeft);
    anchorLayout->addAnchor(label, Fw::AnchorTop, "parent", Fw::AnchorTop);
    label->setText("Dialog body");

    g_dispatcher.poll();

    EXPECT_EQ(5, label->getWidth());

    label->destroy();
    container->destroy();
}
