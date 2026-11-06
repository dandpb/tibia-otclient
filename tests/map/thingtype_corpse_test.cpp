#include <gtest/gtest.h>
#include <client/thingtype.h>
#include <appearances.pb.h>

TEST(ThingTypeCorpse, UsesExplicitAppearanceMetadataWithoutChangingRenderingFlag)
{
    ThingType type;
    appearances::AppearanceFlags flags;
    flags.set_corpse(true);
    type.applyAppearanceFlags(flags);
    EXPECT_TRUE(type.isCorpse());
    EXPECT_FALSE(type.isLyingCorpse());
}

TEST(ThingTypeCorpse, OrdinaryContainersAreNotCorpses)
{
    ThingType type;
    appearances::AppearanceFlags flags;
    flags.set_container(true);
    type.applyAppearanceFlags(flags);
    EXPECT_TRUE(type.isContainer());
    EXPECT_FALSE(type.isCorpse());
}
