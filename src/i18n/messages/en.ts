import type ja from "./ja";

type Messages = { [Key in keyof typeof ja]: string };

const en: Messages = {
  appName: "SF6 Rating",
  foundationTitle: "Project foundation",
  foundationDescription: "The application foundation is ready.",
  switchLocale: "日本語",
  loading: "Loading…",
  retry: "Try again",
  errorTitle: "Something went wrong",
  errorDescription: "Please try again.",
  notFoundTitle: "Page not found",
  notFoundDescription: "The page you requested does not exist.",
  backHome: "Back home",
};

export default en;
