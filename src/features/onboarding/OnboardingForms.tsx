"use client";

import { useActionState, useMemo, useState } from "react";
import {
  completeOnboardingAction,
  saveAccountStepAction,
  saveSf6InfoStepAction,
} from "@/features/account/actions";
import {
  initialActionState,
  type ActionState,
} from "@/features/account/action-state";
import type { OnboardingState } from "@/features/account/queries";
import { feedbackMessage } from "@/features/account/feedback";

type SharedProps = {
  locale: "ja" | "en";
  idempotencyKey: string;
  state: OnboardingState;
  labels: Record<string, string>;
};

function ResultMessage({
  locale,
  state,
}: {
  locale: "ja" | "en";
  state: ActionState;
}) {
  if (!state.message) return null;
  return (
    <p
      className={state.status === "error" ? "form-error" : "form-success"}
      role={state.status === "error" ? "alert" : "status"}
    >
      {feedbackMessage(locale, state.message)}
    </p>
  );
}

export function AccountStepForm(
  props: SharedProps & {
    providerAvatarAvailable: boolean;
    providerUsernameCandidate: string | null;
  },
) {
  const [actionState, action, pending] = useActionState(
    saveAccountStepAction,
    initialActionState,
  );
  return (
    <form action={action} className="stack-form">
      <input name="locale" type="hidden" value={props.locale} />
      <input name="idempotencyKey" type="hidden" value={props.idempotencyKey} />
      <label>
        <span>{props.labels.usernameLabel}</span>
        <input
          aria-describedby="username-help"
          defaultValue={
            props.state.username ?? props.providerUsernameCandidate ?? ""
          }
          maxLength={80}
          name="username"
          required
        />
      </label>
      <p className="field-help" id="username-help">
        {props.labels.usernameHelp}
      </p>
      {props.state.avatar_url ? (
        /* eslint-disable-next-line @next/next/no-img-element */
        <img
          alt=""
          className="avatar-preview"
          height="96"
          src={props.state.avatar_url}
          width="96"
        />
      ) : null}
      {props.providerAvatarAvailable &&
      props.state.avatar_source === "default" ? (
        <label>
          <span>{props.labels.providerAvatarCandidate}</span>
          {/* The authenticated route returns a processed WebP and keeps the
              provider URL out of the browser. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            alt=""
            className="avatar-preview"
            height="96"
            src="/auth/provider-avatar"
            width="96"
          />
          <span>
            <input defaultChecked name="useProviderAvatar" type="checkbox" />
            {props.labels.useProviderAvatar}
          </span>
        </label>
      ) : null}
      <label>
        <span>{props.labels.avatarLabel}</span>
        <input
          accept="image/jpeg,image/png,image/webp"
          name="avatar"
          type="file"
        />
      </label>
      <ResultMessage locale={props.locale} state={actionState} />
      <button className="button" disabled={pending} type="submit">
        {pending ? "…" : props.labels.next}
      </button>
    </form>
  );
}

type Region = {
  code: string;
  country_code: string;
  name_ja: string;
  name_en: string;
  sort_order: number;
};

export function Sf6InfoStepForm(
  props: SharedProps & {
    countries: { code: string; label: string }[];
    regions: Region[];
  },
) {
  const [actionState, action, pending] = useActionState(
    saveSf6InfoStepAction,
    initialActionState,
  );
  const initialCountry = props.state.country_code ?? "JP";
  const [country, setCountry] = useState(initialCountry);
  const availableRegions = useMemo(
    () => props.regions.filter((region) => region.country_code === country),
    [country, props.regions],
  );
  return (
    <form action={action} className="stack-form">
      <input name="locale" type="hidden" value={props.locale} />
      <input name="idempotencyKey" type="hidden" value={props.idempotencyKey} />
      <label>
        <span>{props.labels.playerNameLabel}</span>
        <input
          defaultValue={props.state.sf6_player_name ?? ""}
          maxLength={128}
          name="playerName"
          required
        />
      </label>
      <label>
        <span>{props.labels.userCodeLabel}</span>
        <input
          aria-describedby="user-code-help"
          defaultValue={props.state.sf6_user_code ?? ""}
          inputMode="numeric"
          name="userCode"
          required
        />
      </label>
      <p className="field-help" id="user-code-help">
        {props.labels.userCodeHelp}
      </p>
      <label>
        <span>{props.labels.countryLabel}</span>
        <select
          name="countryCode"
          onChange={(event) => setCountry(event.target.value)}
          value={country}
        >
          {props.countries.map(({ code, label }) => (
            <option key={code} value={code}>
              {label} ({code})
            </option>
          ))}
        </select>
      </label>
      <label>
        <span>{props.labels.regionLabel}</span>
        <select
          defaultValue={
            availableRegions.some(
              (region) => region.code === props.state.broad_region_code,
            )
              ? (props.state.broad_region_code ?? availableRegions[0]?.code)
              : availableRegions[0]?.code
          }
          key={country}
          name="broadRegionCode"
          required
        >
          {availableRegions.map((region) => (
            <option key={region.code} value={region.code}>
              {props.locale === "ja" ? region.name_ja : region.name_en}
            </option>
          ))}
        </select>
      </label>
      <ResultMessage locale={props.locale} state={actionState} />
      <button className="button" disabled={pending} type="submit">
        {pending ? "…" : props.labels.next}
      </button>
    </form>
  );
}

type Character = { code: string; name: string; sort_order: number };

export function RatingSetupForm(
  props: SharedProps & { characters: Character[] },
) {
  const [actionState, action, pending] = useActionState(
    completeOnboardingAction,
    initialActionState,
  );
  const previewRank =
    typeof actionState.result?.rank === "string"
      ? actionState.result.rank
      : null;
  const previewCharacter =
    typeof actionState.result?.character_code === "string"
      ? actionState.result.character_code
      : null;
  const previewRankTier =
    typeof actionState.result?.rank_tier === "number"
      ? actionState.result.rank_tier
      : null;
  const previewMasterRating =
    typeof actionState.result?.master_rating === "number"
      ? actionState.result.master_rating
      : null;
  const [rank, setRank] = useState<string>(
    previewRank ?? props.state.sf6_rank ?? "rookie",
  );
  const previewToken =
    typeof actionState.result?.preview_token === "string"
      ? actionState.result.preview_token
      : "";
  const previewRenderKey =
    typeof actionState.result?.preview_render_key === "string"
      ? actionState.result.preview_render_key
      : "rating-preview-pending";
  const [previewDirty, setPreviewDirty] = useState(true);

  return (
    <form
      action={action}
      className="stack-form"
      key={previewRenderKey}
      onChange={() => setPreviewDirty(true)}
    >
      <input name="locale" type="hidden" value={props.locale} />
      <input name="idempotencyKey" type="hidden" value={props.idempotencyKey} />
      <input
        name="previewToken"
        type="hidden"
        value={previewDirty ? "" : previewToken}
      />
      <label>
        <span>{props.labels.characterLabel}</span>
        <select
          defaultValue={
            previewCharacter ?? props.state.main_character_code ?? "ryu"
          }
          name="characterCode"
          required
        >
          {props.characters.map((character) => (
            <option key={character.code} value={character.code}>
              {character.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        <span>{props.labels.rankLabel}</span>
        <select
          name="rank"
          onChange={(event) => setRank(event.target.value)}
          value={rank}
        >
          {[
            "rookie",
            "iron",
            "bronze",
            "silver",
            "gold",
            "platinum",
            "diamond",
            "master",
          ].map((value) => (
            <option key={value} value={value}>
              {value[0].toUpperCase() + value.slice(1)}
            </option>
          ))}
        </select>
      </label>
      {rank === "master" ? (
        <label>
          <span>{props.labels.masterRatingLabel}</span>
          <input
            defaultValue={
              previewMasterRating ?? props.state.master_rating ?? 1500
            }
            inputMode="numeric"
            max={5000}
            min={1}
            name="masterRating"
            required
            type="number"
          />
        </label>
      ) : (
        <label>
          <span>{props.labels.rankTierLabel}</span>
          <select
            defaultValue={previewRankTier ?? props.state.sf6_rank_tier ?? 3}
            name="rankTier"
          >
            {[1, 2, 3, 4, 5].map((tier) => (
              <option key={tier} value={tier}>
                {tier}
              </option>
            ))}
          </select>
        </label>
      )}
      <p className="field-help">{props.labels.placementExplanation}</p>
      {!previewDirty && actionState.result?.starting_rating ? (
        <output className="rating-preview" aria-live="polite">
          {props.labels.startingRating}: {actionState.result.starting_rating}
        </output>
      ) : null}
      <ResultMessage locale={props.locale} state={actionState} />
      <div className="form-actions">
        <button
          className="button button-secondary"
          disabled={pending}
          name="intent"
          onClick={() => setPreviewDirty(false)}
          type="submit"
          value="preview"
        >
          {props.labels.previewStartingRating}
        </button>
        <button
          className="button"
          disabled={pending || previewDirty || !previewToken}
          name="intent"
          type="submit"
          value="complete"
        >
          {pending ? "…" : props.labels.completeOnboarding}
        </button>
      </div>
    </form>
  );
}
