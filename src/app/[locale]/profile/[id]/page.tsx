import Image from "next/image";
import { notFound } from "next/navigation";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import { createClient } from "@/lib/supabase/server";

export default async function PublicProfilePage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale, id } = await params;
  if (!isLocale(locale)) notFound();
  const supabase = await createClient();
  const { data: profile, error } = await supabase
    .from("public_profiles")
    .select(
      "id,username,avatar_url,country_code,current_rating,placement_status,placement_completed_count",
    )
    .eq("id", id)
    .maybeSingle();
  if (error || !profile) notFound();
  const messages = getMessages(locale);
  const countryNames = new Intl.DisplayNames([locale], { type: "region" });
  return (
    <article
      className="panel public-profile"
      aria-labelledby="public-profile-title"
    >
      {profile.avatar_url ? (
        <Image
          alt=""
          className="avatar-preview"
          height={128}
          src={profile.avatar_url}
          unoptimized
          width={128}
        />
      ) : (
        <div className="avatar-placeholder" />
      )}
      <h1 id="public-profile-title">{profile.username}</h1>
      <dl>
        <div>
          <dt>{messages.countryLabel}</dt>
          <dd>
            {countryNames.of(profile.country_code ?? "") ??
              profile.country_code}
          </dd>
        </div>
        <div>
          <dt>{messages.currentRating}</dt>
          <dd>{profile.current_rating}</dd>
        </div>
        <div>
          <dt>{messages.placement}</dt>
          <dd>
            {profile.placement_status} ({profile.placement_completed_count}/10)
          </dd>
        </div>
      </dl>
    </article>
  );
}
