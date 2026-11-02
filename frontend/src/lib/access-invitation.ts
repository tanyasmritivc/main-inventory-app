export type AccessInvitation = {
  invitation_id: string;
  scope: "organization" | "workspace" | "inventory";
  resource_id: string;
  organization_id?: string | null;
  team_id?: string | null;
  inventory_id?: string | null;
  name: string;
  role: string;
  recipient_email?: string;
  invited_by_name?: string;
  status: "pending" | "accepted" | "declined" | "cancelled" | "expired";
  expires_at: string;
  created_at: string;
  destination: string;
};
export type InvitationDelivery = { invitation: AccessInvitation; code: string; invite_url: string; email_sent: boolean };
export const invitationRole = (role: string) => role === "inherit" ? "Use workspace default" : role.charAt(0).toUpperCase() + role.slice(1);
