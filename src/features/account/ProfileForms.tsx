"use client";

import Image from "next/image";
import { useActionState, useMemo, useState } from "react";
import {
  deleteAvatarAction,
  replaceAvatarAction,
  requestAccountDeletionAction,
  updateProfileDetailsAction,
  updateSf6IdentityAction,
  updateUsernameAction,
} from "./actions";
import { initialActionState, type ActionState } from "./action-state";
import type { OnboardingState } from "./queries";
import { feedbackMessage } from "./feedback";

type Labels = Record<string, string>;
type CommonProps = {
  locale: "ja" | "en";
  labels: Labels;
  state: OnboardingState;
  idempotencyKey: string;
};

function Feedback({
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

function FormShell({
  action,
  children,
  idempotencyKey,
  locale,
  submitLabel,
}: {
  action: (state: ActionState, formData: FormData) => Promise<ActionState>;
  children: React.ReactNode;
  idempotencyKey: string;
  locale: "ja" | "en";
  submitLabel: string;
}) {
  const [state, formAction, pending] = useActionState(
    action,
    initialActionState,
  );
  return (
    <form action={formAction} className="stack-form settings-form">
      <input name="locale" type="hidden" value={locale} />
      <input name="idempotencyKey" type="hidden" value={idempotencyKey} />
      {children}
      <Feedback locale={locale} state={state} />
      <button className="button" disabled={pending} type="submit">
        {pending ? "…" : submitLabel}
      </button>
    </form>
  );
}

export function UsernameSettings(props: CommonProps) {
  return (
    <FormShell
      action={updateUsernameAction}
      idempotencyKey={props.idempotencyKey}
      locale={props.locale}
      submitLabel={props.labels.save}
    >
      <label>
        <span>{props.labels.usernameLabel}</span>
        <input
          defaultValue={props.state.username ?? ""}
          name="username"
          required
        />
      </label>
      {props.state.username_changed_at ? (
        <p className="field-help">
          {props.labels.lastChanged}:{" "}
          {new Date(props.state.username_changed_at).toLocaleString(
            props.locale,
          )}
        </p>
      ) : null}
    </FormShell>
  );
}

export function IdentitySettings(props: CommonProps) {
  return (
    <FormShell
      action={updateSf6IdentityAction}
      idempotencyKey={props.idempotencyKey}
      locale={props.locale}
      submitLabel={props.labels.save}
    >
      <label>
        <span>{props.labels.playerNameLabel}</span>
        <input
          defaultValue={props.state.sf6_player_name ?? ""}
          name="playerName"
          required
        />
      </label>
      <label>
        <span>{props.labels.userCodeLabel}</span>
        <input
          defaultValue={props.state.sf6_user_code ?? ""}
          inputMode="numeric"
          name="userCode"
          required
        />
      </label>
      {props.state.sf6_user_code_changed_at ? (
        <p className="field-help">
          {props.labels.userCodeLastChanged}:{" "}
          {new Date(props.state.sf6_user_code_changed_at).toLocaleString(
            props.locale,
          )}
        </p>
      ) : null}
    </FormShell>
  );
}

export function AvatarSettings(props: CommonProps) {
  const [replaceState, replaceAction, replacePending] = useActionState(
    replaceAvatarAction,
    initialActionState,
  );
  const [deleteState, deleteAction, deletePending] = useActionState(
    deleteAvatarAction,
    initialActionState,
  );
  return (
    <div className="settings-form">
      {props.state.avatar_url ? (
        <Image
          alt=""
          className="avatar-preview"
          height={128}
          src={props.state.avatar_url}
          unoptimized
          width={128}
        />
      ) : (
        <div aria-label="Default avatar" className="avatar-placeholder" />
      )}
      <form action={replaceAction} className="stack-form">
        <input name="locale" type="hidden" value={props.locale} />
        <input
          name="idempotencyKey"
          type="hidden"
          value={`${props.idempotencyKey}:replace`}
        />
        <label>
          <span>{props.labels.avatarLabel}</span>
          <input
            accept="image/jpeg,image/png,image/webp"
            name="avatar"
            required
            type="file"
          />
        </label>
        <Feedback locale={props.locale} state={replaceState} />
        <button className="button" disabled={replacePending} type="submit">
          {replacePending ? "…" : props.labels.save}
        </button>
      </form>
      <form action={deleteAction}>
        <input name="locale" type="hidden" value={props.locale} />
        <input
          name="idempotencyKey"
          type="hidden"
          value={`${props.idempotencyKey}:delete`}
        />
        <Feedback locale={props.locale} state={deleteState} />
        <button
          className="button button-danger"
          disabled={deletePending || !props.state.avatar_url}
          type="submit"
        >
          {props.labels.deleteAvatar}
        </button>
      </form>
    </div>
  );
}

type Region = {
  code: string;
  country_code: string;
  name_ja: string;
  name_en: string;
  sort_order: number;
};
type Character = { code: string; name: string; sort_order: number };

export function DetailsSettings(
  props: CommonProps & {
    countries: { code: string; label: string }[];
    regions: Region[];
    characters: Character[];
  },
) {
  const [country, setCountry] = useState(props.state.country_code ?? "JP");
  const [rank, setRank] = useState<string>(props.state.sf6_rank ?? "rookie");
  const regions = useMemo(
    () => props.regions.filter((region) => region.country_code === country),
    [country, props.regions],
  );
  return (
    <FormShell
      action={updateProfileDetailsAction}
      idempotencyKey={props.idempotencyKey}
      locale={props.locale}
      submitLabel={props.labels.save}
    >
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
            regions.some(
              (region) => region.code === props.state.broad_region_code,
            )
              ? (props.state.broad_region_code ?? regions[0]?.code)
              : regions[0]?.code
          }
          key={country}
          name="broadRegionCode"
        >
          {regions.map((region) => (
            <option key={region.code} value={region.code}>
              {props.locale === "ja" ? region.name_ja : region.name_en}
            </option>
          ))}
        </select>
      </label>
      <label>
        <span>{props.labels.characterLabel}</span>
        <select
          defaultValue={props.state.main_character_code ?? "ryu"}
          name="characterCode"
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
              {value}
            </option>
          ))}
        </select>
      </label>
      {rank === "master" ? (
        <label>
          <span>{props.labels.masterRatingLabel}</span>
          <input
            defaultValue={props.state.master_rating ?? 1500}
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
          <select defaultValue={props.state.sf6_rank_tier ?? 3} name="rankTier">
            {[1, 2, 3, 4, 5].map((tier) => (
              <option key={tier} value={tier}>
                {tier}
              </option>
            ))}
          </select>
        </label>
      )}
      <p className="field-help">{props.labels.noRatingRecalculation}</p>
    </FormShell>
  );
}

export function DeleteAccountSettings(props: CommonProps) {
  const [state, action, pending] = useActionState(
    requestAccountDeletionAction,
    initialActionState,
  );
  return (
    <form action={action} className="stack-form danger-zone">
      <input name="locale" type="hidden" value={props.locale} />
      <input name="idempotencyKey" type="hidden" value={props.idempotencyKey} />
      <p>{props.labels.deleteAccountWarning}</p>
      <label className="checkbox-label">
        <input name="confirmed" required type="checkbox" />
        <span>{props.labels.irreversibleConfirmation}</span>
      </label>
      <Feedback locale={props.locale} state={state} />
      <button className="button button-danger" disabled={pending} type="submit">
        {pending ? "…" : props.labels.deleteAccountSubmit}
      </button>
    </form>
  );
}
