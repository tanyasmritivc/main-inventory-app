'use client'
import { useEffect, useRef } from 'react'
import { Renderer, Program, Mesh, Triangle, Vec2 } from 'ogl'

interface SpecularButtonProps {
  children?: React.ReactNode
  size?: 'sm' | 'md' | 'lg'
  radius?: number
  tint?: string
  tintOpacity?: number
  blur?: number
  textColor?: string
  lineColor?: string
  baseColor?: string
  intensity?: number
  shineSize?: number
  shineFade?: number
  thickness?: number
  speed?: number
  followMouse?: boolean
  proximity?: number
  autoAnimate?: boolean
  onClick?: () => void
  className?: string
  style?: React.CSSProperties
}

export default function SpecularButton({
  children,
  size = 'lg',
  radius = 18,
  tint = '#ffffff',
  tintOpacity = 0,
  blur = 0,
  textColor = '#f5f5f5',
  lineColor = '#ffffff',
  baseColor = '#525252',
  intensity = 1,
  shineSize = 10,
  shineFade = 40,
  thickness = 1,
  speed = 0.35,
  followMouse = true,
  proximity = 250,
  autoAnimate = false,
  onClick,
  className = '',
  style = {},
}: SpecularButtonProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const mouseRef = useRef({ x: 0.5, y: 0.5 })
  const targetRef = useRef({ x: 0.5, y: 0.5 })
  const rendererRef = useRef<Renderer | null>(null)
  const rafRef = useRef<number>(0)

  const sizeMap = { sm: { h: 36, px: 16, text: 14 }, md: { h: 44, px: 22, text: 15 }, lg: { h: 52, px: 28, text: 16 } }
  const s = sizeMap[size]

  useEffect(() => {
    const canvas = canvasRef.current
    const container = containerRef.current
    if (!canvas || !container) return

    const renderer = new Renderer({ canvas, alpha: true, antialias: true })
    rendererRef.current = renderer
    const gl = renderer.gl
    gl.clearColor(0, 0, 0, 0)

    const geometry = new Triangle(gl)

    const hexToVec3 = (hex: string) => {
      const r = parseInt(hex.slice(1, 3), 16) / 255
      const g = parseInt(hex.slice(3, 5), 16) / 255
      const b = parseInt(hex.slice(5, 7), 16) / 255
      return [r, g, b]
    }

    const program = new Program(gl, {
      vertex: `attribute vec2 uv; attribute vec2 position; varying vec2 vUv; void main() { vUv = uv; gl_Position = vec4(position, 0, 1); }`,
      fragment: `
        precision highp float;
        varying vec2 vUv;
        uniform vec2 uResolution;
        uniform vec2 uMouse;
        uniform float uRadius;
        uniform vec3 uTint;
        uniform float uTintOpacity;
        uniform float uBlur;
        uniform vec3 uLineColor;
        uniform vec3 uBaseColor;
        uniform float uIntensity;
        uniform float uShineSize;
        uniform float uShineFade;
        uniform float uThickness;
        uniform float uTime;
        uniform float uSpeed;

        float roundedBox(vec2 p, vec2 b, float r) {
          vec2 q = abs(p) - b + r;
          return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
        }

        void main() {
          vec2 uv = vUv;
          vec2 res = uResolution;
          vec2 p = uv * res;
          vec2 center = res * 0.5;
          vec2 b = center - uRadius;

          float d = roundedBox(p - center, b, uRadius);
          float border = smoothstep(uThickness + 0.5, uThickness - 0.5, abs(d));

          vec2 mousePos = uMouse * res;
          vec2 toMouse = normalize(mousePos - p);
          float dist = length(mousePos - p);

          float shine = pow(max(0.0, 1.0 - dist / uShineSize), uShineFade) * uIntensity;
          vec3 col = mix(uBaseColor, uLineColor, shine);

          vec3 tintColor = uTint * uTintOpacity;
          float insideMask = 1.0 - smoothstep(-0.5, 0.5, d);
          vec3 bg = tintColor * insideMask;

          float blurMask = insideMask;
          col = mix(bg, col, border);
          gl_FragColor = vec4(col, border + blurMask * uTintOpacity);
        }
      `,
      uniforms: {
        uResolution: { value: new Vec2(1, 1) },
        uMouse: { value: new Vec2(0.5, 0.5) },
        uRadius: { value: radius },
        uTint: { value: hexToVec3(tint) },
        uTintOpacity: { value: tintOpacity },
        uBlur: { value: blur },
        uLineColor: { value: hexToVec3(lineColor) },
        uBaseColor: { value: hexToVec3(baseColor) },
        uIntensity: { value: intensity },
        uShineSize: { value: shineSize },
        uShineFade: { value: shineFade },
        uThickness: { value: thickness },
        uTime: { value: 0 },
        uSpeed: { value: speed },
      },
    })

    const mesh = new Mesh(gl, { geometry, program })

    const resize = () => {
      const rect = container.getBoundingClientRect()
      renderer.setSize(rect.width, rect.height)
      program.uniforms.uResolution.value = new Vec2(rect.width, rect.height)
      program.uniforms.uRadius.value = radius
    }
    resize()
    window.addEventListener('resize', resize)

    const onMouseMove = (e: MouseEvent) => {
      if (!followMouse) return
      const rect = container.getBoundingClientRect()
      const dx = e.clientX - rect.left
      const dy = e.clientY - rect.top
      const dist = Math.sqrt((dx - rect.width / 2) ** 2 + (dy - rect.height / 2) ** 2)
      if (dist < proximity) {
        targetRef.current = { x: dx / rect.width, y: 1 - dy / rect.height }
      }
    }
    window.addEventListener('mousemove', onMouseMove)

    let t = 0
    const animate = () => {
      rafRef.current = requestAnimationFrame(animate)
      t += 0.016 * speed
      program.uniforms.uTime.value = t

      mouseRef.current.x += (targetRef.current.x - mouseRef.current.x) * 0.08
      mouseRef.current.y += (targetRef.current.y - mouseRef.current.y) * 0.08
      program.uniforms.uMouse.value = new Vec2(mouseRef.current.x, mouseRef.current.y)

      renderer.render({ scene: mesh })
    }
    animate()

    return () => {
      cancelAnimationFrame(rafRef.current)
      window.removeEventListener('resize', resize)
      window.removeEventListener('mousemove', onMouseMove)
    }
  }, [radius, tint, tintOpacity, blur, lineColor, baseColor, intensity, shineSize, shineFade, thickness, speed, followMouse, proximity])

  return (
    <div
      ref={containerRef}
      onClick={onClick}
      className={className}
      style={{
        position: 'relative',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        height: `${s.h}px`,
        padding: `0 ${s.px}px`,
        cursor: 'pointer',
        borderRadius: `${radius}px`,
        ...style,
      }}
    >
      <canvas
        ref={canvasRef}
        style={{
          position: 'absolute',
          inset: 0,
          width: '100%',
          height: '100%',
          borderRadius: `${radius}px`,
        }}
      />
      <span style={{
        position: 'relative',
        zIndex: 1,
        fontSize: `${s.text}px`,
        fontWeight: 500,
        color: textColor,
        letterSpacing: '-0.01em',
        fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
        userSelect: 'none',
        whiteSpace: 'nowrap',
      }}>
        {children}
      </span>
    </div>
  )
}
