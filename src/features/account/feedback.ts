const feedback = {
  ja: {
    auth_failed:
      "認証を完了できませんでした。入力またはリンクを確認してください。",
    auth_invalid_input: "入力内容を確認してください。",
    verification_sent: "確認メールを送信しました。",
    password_reset_sent: "パスワード再設定メールを送信しました。",
    password_too_short: "パスワードは8文字以上にしてください。",
    username_length: "Usernameは3〜20文字にしてください。",
    username_characters: "Usernameに使用できない文字が含まれています。",
    username_too_complex: "Usernameが長すぎるか複雑すぎます。",
    username_reserved: "このUsernameは使用できません。",
    username_cooldown: "Usernameは30日に1回だけ変更できます。",
    player_name_length: "SF6 Player Nameは1〜32文字にしてください。",
    player_name_characters:
      "SF6 Player Nameに使用できない文字が含まれています。",
    sf6_user_code_format: "SF6 User Codeは10桁の数字で入力してください。",
    sf6_user_code_reserved: "このSF6 User CodeはAdminによる確認が必要です。",
    sf6_user_code_cooldown: "SF6 User Codeは30日に1回だけ変更できます。",
    sf6_identity_locked_by_active_match:
      "Active Match中はSF6 Player NameとUser Codeを変更できません。",
    invalid_character: "Main Characterを選択してください。",
    invalid_rank: "SF6 Rankを選択してください。",
    invalid_rating_setup: "Rank tierまたはMaster MRを確認してください。",
    rating_preview_required:
      "現在の入力でStarting Ratingを確認してから完了してください。",
    rating_preview_stale:
      "Starting Ratingの設定が更新されました。もう一度確認してください。",
    avatar_size: "Avatarは5MB以下にしてください。",
    avatar_format: "AvatarはJPEG、PNG、WebPの静止画像だけ使用できます。",
    avatar_animated: "アニメーション画像は使用できません。",
    avatar_decode: "画像を読み取れませんでした。",
    avatar_dimensions: "画像サイズを確認してください。",
    avatar_pixels: "画像の解像度が大きすぎます。",
    avatar_processing: "画像を処理できませんでした。",
    avatar_upload: "Avatarをアップロードできませんでした。",
    avatar_attach: "AvatarをProfileへ反映できませんでした。",
    avatar_required: "Avatarファイルを選択してください。",
    avatar_cleanup_failed:
      "以前のAvatarを削除できませんでした。再試行してください。",
    avatar_cleanup_required: "Avatar削除の完了後に再試行してください。",
    value_already_in_use: "この値はすでに使用されています。",
    rate_limit_exceeded:
      "操作回数が上限に達しました。時間をおいて再試行してください。",
    email_verification_required: "メール確認を完了してください。",
    reauthentication_required:
      "安全のため、再度サインインしてから実行してください。",
    deletion_confirmation_required: "削除確認にチェックしてください。",
    deletion_pending_blocked:
      "削除を受け付けました。進行中のMatch、Result、Dispute解消後に続行します。",
    deletion_blocked: "進行中の処理があるため、まだ匿名化できません。",
    active_match: "Active Matchを完了または解消してください。",
    unresolved_result: "未解決のResultを完了してください。",
    open_dispute: "進行中のDisputeが解決されるまでお待ちください。",
    deletion_retry_required: "削除処理の再試行が必要です。",
    deletion_failed: "削除を開始できませんでした。再試行してください。",
    rating_preview: "Starting Ratingを計算しました。",
    saved: "保存しました。",
    saved_no_rating_recalculation:
      "保存しました。Current RatingとPlacementは再計算されません。",
    save_failed: "保存できませんでした。再試行してください。",
  },
  en: {
    auth_failed:
      "Authentication could not be completed. Check your input or link.",
    auth_invalid_input: "Check the entered information.",
    verification_sent: "Verification email sent.",
    password_reset_sent: "Password reset email sent.",
    password_too_short: "Use a password of at least 8 characters.",
    username_length: "Username must contain 3–20 characters.",
    username_characters: "Username contains an unsupported character.",
    username_too_complex: "Username is too long or complex.",
    username_reserved: "This Username cannot be used.",
    username_cooldown: "Username can be changed once every 30 days.",
    player_name_length: "SF6 Player Name must contain 1–32 characters.",
    player_name_characters:
      "SF6 Player Name contains an unsupported character.",
    sf6_user_code_format: "Enter the SF6 User Code as 10 digits.",
    sf6_user_code_reserved: "This SF6 User Code requires Admin review.",
    sf6_user_code_cooldown: "SF6 User Code can be changed once every 30 days.",
    sf6_identity_locked_by_active_match:
      "SF6 Player Name and User Code cannot change during an Active Match.",
    invalid_character: "Select a Main Character.",
    invalid_rank: "Select an SF6 Rank.",
    invalid_rating_setup: "Check the Rank tier or Master MR.",
    rating_preview_required:
      "Preview Starting Rating for the current input before completing.",
    rating_preview_stale: "Starting Rating settings changed. Preview it again.",
    avatar_size: "Avatar must be 5 MB or smaller.",
    avatar_format: "Use a static JPEG, PNG, or WebP Avatar.",
    avatar_animated: "Animated images are not supported.",
    avatar_decode: "The image could not be read.",
    avatar_dimensions: "Check the image dimensions.",
    avatar_pixels: "The image resolution is too large.",
    avatar_processing: "The image could not be processed.",
    avatar_upload: "The Avatar could not be uploaded.",
    avatar_attach: "The Avatar could not be attached to the Profile.",
    avatar_required: "Select an Avatar file.",
    avatar_cleanup_failed:
      "The previous Avatar could not be removed. Try again.",
    avatar_cleanup_required: "Try again after Avatar cleanup completes.",
    value_already_in_use: "This value is already in use.",
    rate_limit_exceeded: "Too many attempts. Wait and try again.",
    email_verification_required: "Complete email verification first.",
    reauthentication_required:
      "Sign in again before this security-sensitive action.",
    deletion_confirmation_required: "Confirm account deletion first.",
    deletion_pending_blocked:
      "Deletion is pending until active Matches, Results, or Disputes are resolved.",
    deletion_blocked: "An active dependency prevents anonymization.",
    active_match: "Complete or resolve the Active Match.",
    unresolved_result: "Resolve the outstanding Result.",
    open_dispute: "Wait until the open Dispute is resolved.",
    deletion_retry_required: "Account deletion must be retried.",
    deletion_failed: "Account deletion could not start. Try again.",
    rating_preview: "Starting Rating calculated.",
    saved: "Saved.",
    saved_no_rating_recalculation:
      "Saved. Current Rating and Placement were not recalculated.",
    save_failed: "Could not save. Try again.",
  },
} as const;

export function feedbackMessage(locale: "ja" | "en", code: string) {
  const localized = feedback[locale] as Record<string, string>;
  return localized[code] ?? localized.save_failed;
}
