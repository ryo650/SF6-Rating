"use client";

import { useActionState } from "react";
import type { ActionState } from "@/features/account/action-state";
import { initialActionState } from "@/features/account/action-state";
import { feedbackMessage } from "@/features/account/feedback";

type AuthFormProps = {
  locale: "ja" | "en";
  mode: "sign-in" | "sign-up" | "resend" | "forgot" | "update";
  action: (state: ActionState, formData: FormData) => Promise<ActionState>;
  labels: {
    email: string;
    password: string;
    submit: string;
  };
};

export function AuthForm({ locale, mode, action, labels }: AuthFormProps) {
  const [state, formAction, pending] = useActionState(
    action,
    initialActionState,
  );
  const needsEmail = mode !== "update";
  const needsPassword =
    mode === "sign-in" || mode === "sign-up" || mode === "update";

  return (
    <form action={formAction} className="stack-form">
      <input name="locale" type="hidden" value={locale} />
      {needsEmail ? (
        <label>
          <span>{labels.email}</span>
          <input
            autoComplete="email"
            inputMode="email"
            name="email"
            required
            type="email"
          />
        </label>
      ) : null}
      {needsPassword ? (
        <label>
          <span>{labels.password}</span>
          <input
            autoComplete={
              mode === "sign-in" ? "current-password" : "new-password"
            }
            minLength={8}
            name="password"
            required
            type="password"
          />
        </label>
      ) : null}
      {state.message ? (
        <p
          className={state.status === "error" ? "form-error" : "form-success"}
          role={state.status === "error" ? "alert" : "status"}
        >
          {feedbackMessage(locale, state.message)}
        </p>
      ) : null}
      <button className="button" disabled={pending} type="submit">
        {pending ? "…" : labels.submit}
      </button>
    </form>
  );
}
