// A comic page in the game's palette: a lifted panel mid-slide, a loose word
// leaving its speech bubble, and Nib on the floor below. Pure SVG, so the
// landing page needs no image download.
export function HeroArt() {
  return (
    <svg className="hero-art" viewBox="0 0 480 320" role="img" aria-labelledby="hero-art-title">
      <title id="hero-art-title">
        A comic page. One panel is lifted and sliding, and the word OPEN floats out of a speech bubble towards a door.
      </title>
      <defs>
        <pattern id="dots" width="8" height="8" patternUnits="userSpaceOnUse">
          <circle cx="2" cy="2" r="1.3" fill="#e0d1ad" />
        </pattern>
      </defs>
      <rect width="480" height="320" fill="#f7f1e1" />

      {/* Top left: the little room, with a speech bubble. */}
      <rect x="16" y="16" width="208" height="132" fill="#f2e8cf" stroke="#1d1b26" strokeWidth="3" />
      <rect x="18" y="96" width="204" height="40" fill="url(#dots)" />
      <rect x="18" y="128" width="204" height="18" fill="#e0d1ad" />
      <path d="M40 34h152a8 8 0 0 1 8 8v26a8 8 0 0 1-8 8H92l-14 14v-14H40a8 8 0 0 1-8-8V42a8 8 0 0 1 8-8z" fill="#fffcf3" stroke="#1d1b26" strokeWidth="2.5" />
      <text x="48" y="60" fontFamily="ui-monospace, Menlo, monospace" fontSize="13" fontWeight="600" fill="#1d1b26">THE DOOR IS</text>
      <rect x="146" y="47" width="42" height="18" fill="none" stroke="#c44536" strokeWidth="1.5" strokeDasharray="3 2" />

      {/* Top right: a lifted panel, mid-slide, with its shadow left behind. */}
      <rect x="256" y="34" width="208" height="132" fill="#c9b994" />
      <rect x="248" y="22" width="208" height="132" fill="#f2e8cf" stroke="#1d1b26" strokeWidth="3" strokeDasharray="10 6" />
      <rect x="250" y="128" width="204" height="24" fill="#e0d1ad" />
      <path d="M352 168v22m-8-8 8 8 8-8" stroke="#1d1b26" strokeWidth="2.5" fill="none" strokeLinecap="round" />

      {/* Bottom: the room with the door. */}
      <rect x="16" y="196" width="448" height="108" fill="#f2e8cf" stroke="#1d1b26" strokeWidth="3" />
      <rect x="18" y="250" width="444" height="36" fill="url(#dots)" />
      <rect x="18" y="284" width="444" height="18" fill="#e0d1ad" />
      <rect x="388" y="226" width="40" height="58" fill="#1d1b26" />
      <path d="M402 284l26-26v26z" fill="#fbf7ea" />
      <rect x="380" y="208" width="56" height="16" fill="#fffcf3" stroke="#c44536" strokeWidth="1.5" strokeDasharray="3 2" />

      {/* The loose word, on its way from the bubble to the door's label. */}
      <path d="M167 66c60 50 150 70 236 128" stroke="#c44536" strokeWidth="1.5" strokeDasharray="4 4" fill="none" />
      <g transform="rotate(-6 300 150)">
        <rect x="270" y="138" width="62" height="24" fill="#fffcf3" stroke="#1d1b26" strokeWidth="2.5" />
        <text x="301" y="155" textAnchor="middle" fontFamily="ui-monospace, Menlo, monospace" fontSize="14" fontWeight="800" fill="#c44536">OPEN</text>
      </g>

      {/* Nib: a small ink figure with a red scarf. */}
      <g transform="translate(120 258)">
        <rect x="0" y="0" width="16" height="26" rx="5" fill="#1d1b26" />
        <rect x="-2" y="10" width="20" height="4" fill="#c44536" />
        <path d="M16 12l8 4-8 1z" fill="#c44536" />
        <circle cx="5.5" cy="6" r="1.6" fill="#fbf7ea" />
        <circle cx="10.5" cy="6" r="1.6" fill="#fbf7ea" />
      </g>
    </svg>
  );
}
