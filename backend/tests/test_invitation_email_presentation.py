from html.parser import HTMLParser

from app.services.invitation_email import render_invitation_email


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.tags = []
        self.content = []

    def handle_starttag(self, tag, attrs):
        self.tags.append(tag)
        if tag == 'a':
            self.links.append(dict(attrs)['href'])

    def handle_data(self, data):
        self.content.append(data)


def test_untrusted_fields_are_text_and_invitation_links_round_trip():
    value = '<img src=x onerror="alert(1)"> & "Studio"'
    url = 'https://www.findez.ai/join/access?code=ABC123&from=email'
    fallback = 'https://www.findez.ai/join/access'
    html = render_invitation_email(
        title=value, introduction=value, action_label=value, action_url=url,
        code=value, instructions=value, access_label=value, fallback_url=fallback,
    )
    parsed = Links()
    parsed.feed(html)
    assert parsed.tags.count('img') == 1  # Only the static brand image.
    assert parsed.links == [url, fallback]
    assert ''.join(parsed.content).count(value) == 6
    assert 'onerror="' not in html


def test_optional_access_does_not_invent_a_role_or_expiry():
    html = render_invitation_email(
        title='Join Studio', introduction='A team invitation',
        action_label='Open invitation', action_url='https://www.findez.ai/join/team/ABC123',
        code='ABC123', instructions='Open FindEZ to join the team.',
    )
    parsed = Links()
    parsed.feed(html)
    assert parsed.links == ['https://www.findez.ai/join/team/ABC123'] * 2
    assert 'ABC123' in parsed.content
    assert 'Expires' not in html
    assert 'access:' not in html
