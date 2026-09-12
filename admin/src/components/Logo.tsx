import React from 'react'

export function Logo() {
  return (
    <div className="athariyya-logo" aria-label="Makthaba Athariyya Idhaaraa">
      <img className="athariyya-logo__mark" src="/makthaba-logo.png" alt="" />
      <span>
        <strong>މަކްތަބާ އަލްއަޘަރިއްޔާ</strong>
        <small>އިދާރާ</small>
      </span>
    </div>
  )
}

export function Icon() {
  return <img className="athariyya-icon" src="/makthaba-logo.png" alt="Makthaba" />
}
