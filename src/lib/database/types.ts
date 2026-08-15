import type { Database } from "@/lib/supabase/database.types";

export type { Database };

type PublicSchema = Database["public"];

export type TableName = keyof PublicSchema["Tables"];
export type ViewName = keyof PublicSchema["Views"];
export type EnumName = keyof PublicSchema["Enums"];

export type TableRow<Name extends TableName> =
  PublicSchema["Tables"][Name]["Row"];
export type TableInsert<Name extends TableName> =
  PublicSchema["Tables"][Name]["Insert"];
export type TableUpdate<Name extends TableName> =
  PublicSchema["Tables"][Name]["Update"];
export type ViewRow<Name extends ViewName> = PublicSchema["Views"][Name]["Row"];
export type DatabaseEnum<Name extends EnumName> = PublicSchema["Enums"][Name];
