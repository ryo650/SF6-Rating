export type ActionState = {
  status: "idle" | "error" | "success";
  message?: string;
  fieldErrors?: Record<string, string>;
  result?: Record<string, string | number | boolean | null>;
};

export const initialActionState: ActionState = { status: "idle" };
