// FindEZ theme for Tailwind: spread into theme.extend
module.exports = {
  colors: {
    ink: { DEFAULT: '#111112', 2: '#55565B', 3: '#8C8D92' },
    paper: '#F7FAFD', line: '#E8E8EA', night: '#0B0B0D',
    orange: { DEFAULT: '#E8590C', ink: '#C2410C', tint: '#FFE8DA' },
    blue: { DEFAULT: '#A9D6F5', deep: '#6FA9D6', line: '#4E92C9', tint: '#EEF6FD' },
    success: '#1E8E5A', warning: '#F2A33A', danger: '#D93B2B'
  },
  fontFamily: { sans: ['Plus Jakarta Sans', 'ui-sans-serif', 'system-ui'], mono: ['Geist Mono', 'ui-monospace'] },
  borderRadius: { sm: '8px', md: '12px', lg: '18px', xl: '26px', pill: '999px' },
  boxShadow: {
    card: '0 0 0 1px rgba(17,17,18,.06), 0 14px 34px rgba(17,17,18,.08)',
    float: '0 0 0 1px rgba(17,17,18,.06), 0 24px 60px rgba(60,110,150,.18)'
  },
  letterSpacing: { tightest: '-.04em' }
};
