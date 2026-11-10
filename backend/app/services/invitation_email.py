"""Shared presentation for invitation emails. No delivery or access side effects."""

from html import escape


def render_invitation_email(
    *, title: str, introduction: str, action_label: str, action_url: str,
    code: str, instructions: str, access_label: str = "",
    fallback_url: str | None = None,
) -> str:
    """Render plain text fields safely, retaining the caller's invitation URLs."""
    title, introduction, action_label, code, instructions, access_label = (
        escape(value) for value in
        (title, introduction, action_label, code, instructions, access_label)
    )
    link = escape(action_url, quote=True)
    fallback = escape(fallback_url or action_url, quote=True)
    access = (
        f'<p class="primary" style="margin:20px 0 0;font-size:15px;line-height:1.6;'
        f'color:#242629;font-weight:600;">{access_label}</p>' if access_label else ""
    )
    return f'''<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
<title>FindEZ invitation</title>
<style>
@media (prefers-color-scheme: dark) {{
 .canvas {{background:#151517!important;}} .card {{background:#222225!important;border-color:#39393e!important;}}
 .primary {{color:#f5f5f7!important;}} .secondary {{color:#b8bac2!important;}}
 .codebox {{background:#2c2c30!important;border-color:#424247!important;}}
}}
@media only screen and (max-width:480px) {{
 .outer {{padding:24px 12px!important;}} .content {{padding:28px 22px!important;}}
 .heading {{font-size:28px!important;}} .code {{font-size:21px!important;letter-spacing:2px!important;}}
}}
/* Gmail iOS can invert text independently of gradient backgrounds. */
u + .fz-bg .fz-cta-screen {{background:#000;mix-blend-mode:screen;}}
u + .fz-bg .fz-cta-difference {{background:#000;mix-blend-mode:difference;}}
</style></head>
<body class="fz-bg canvas" style="margin:0;padding:0;background:#f6f8f9;font-family:Arial,Helvetica,sans-serif;-webkit-text-size-adjust:100%;">
<table class="canvas" role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" bgcolor="#f6f8f9"><tr><td class="outer" align="center" style="padding:40px 16px;">
<!--[if mso]><table role="presentation" width="560"><tr><td><![endif]-->
<table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width:560px;table-layout:fixed;">
<tr><td style="padding:0 8px 26px;">
<table role="presentation" border="0" cellspacing="0" cellpadding="0"><tr>
<td width="46"><img src="https://findez.ai/favicon.png" width="34" height="34" alt="" style="display:block;border:0;border-radius:9px;"></td>
<td class="primary" style="font-size:25px;font-weight:700;letter-spacing:-1px;color:#242629;">FindEZ</td>
</tr></table></td></tr>
<tr><td class="card content" bgcolor="#ffffff" style="background:#fff;border:1px solid #e3e6ea;border-radius:24px;padding:36px 32px;overflow-wrap:anywhere;word-wrap:break-word;">
<p class="secondary" style="margin:0 0 16px;color:#70757f;font-size:12px;line-height:1.5;letter-spacing:1.5px;font-weight:600;">YOU'RE INVITED</p>
<h1 class="primary heading" style="margin:0 0 16px;color:#242629;font-size:32px;line-height:1.2;letter-spacing:-1px;font-weight:700;">{title}</h1>
<p class="secondary" style="margin:0;color:#626873;font-size:16px;line-height:1.65;">{introduction}</p>
{access}
<table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0"><tr><td style="padding:28px 0;">
<a href="{link}" style="display:block;background:#111111!important;background-image:linear-gradient(#111111,#111111)!important;color:#ffffff!important;padding:17px 20px;border-radius:28px;text-align:center;text-decoration:none;font-size:16px;font-weight:700;line-height:1.4;">
<span class="fz-cta-screen" style="display:block;"><span class="fz-cta-difference" style="display:block;">{action_label}</span></span></a>
</td></tr><tr><td class="codebox" style="background:#f6f8f9;border:1px solid #e3e6ea;border-radius:16px;padding:20px 12px;text-align:center;">
<p class="secondary" style="margin:0 0 10px;color:#70757f;font-size:12px;line-height:1.4;letter-spacing:1px;">INVITATION CODE</p>
<p class="primary code" style="margin:0;color:#242629;font-family:Consolas,Menlo,monospace;font-size:24px;font-weight:700;line-height:1.4;letter-spacing:3px;overflow-wrap:anywhere;">{code}</p>
<p style="margin:12px 0 0;font-size:13px;line-height:1.5;"><a class="secondary" href="{fallback}" style="color:#626873;text-decoration:underline;">Open FindEZ to use this code</a></p>
</td></tr></table>
<p class="secondary" style="margin:24px 0 0;color:#626873;font-size:14px;line-height:1.7;">{instructions}</p>
</td></tr>
<tr><td align="center" style="padding:24px 16px 0;"><p class="secondary" style="margin:0;color:#70757f;font-size:12px;line-height:1.6;">Your things. Your spaces. Together on FindEZ.</p></td></tr>
</table><!--[if mso]></td></tr></table><![endif]-->
</td></tr></table></body></html>'''
