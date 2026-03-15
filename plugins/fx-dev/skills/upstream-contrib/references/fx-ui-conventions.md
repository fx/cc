# fx/ui Repository Conventions

Quick reference for contributing to https://github.com/fx/ui.

## Public Repo Rules

- **No private references** — never mention consumer repos, internal orgs, or private registries
- Describe changes generically (e.g., "Add status variants to Badge" not "Add variants for co dashboard")

## File Locations

| What | Where |
|------|-------|
| Components | `src/components/ui/<component>.tsx` |
| Tests | `src/components/ui/__tests__/<component>.test.tsx` |
| Stories | `src/components/ui/<component>.stories.tsx` |
| Barrel export | `src/index.ts` |
| Theme CSS | `src/styles/globals.css` |
| Utils | `src/lib/utils.ts` |

## Component Pattern

```tsx
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const componentVariants = cva(
  'base-classes...',
  {
    variants: {
      variant: {
        default: '...',
        secondary: '...',
      },
    },
    defaultVariants: { variant: 'default' },
  },
)

function Component({
  className,
  variant,
  ...props
}: React.ComponentProps<'div'> & VariantProps<typeof componentVariants>) {
  return (
    <div data-slot="component" className={cn(componentVariants({ variant }), className)} {...props} />
  )
}

export { Component, componentVariants }
```

## Key Rules

- Named functions (not arrow functions)
- `data-slot="component-name"` on root element
- CVA for all variant definitions
- Export component + variants + types from `src/index.ts`
- React 19 native ref forwarding (no `forwardRef`)
- Biome: 2-space indent, single quotes, 100 char width

## Test Pattern

```tsx
import { render, screen } from '@testing-library/react'

describe('Component', () => {
  it('renders with children', () => {
    render(<Component>Text</Component>)
    expect(screen.getByText('Text')).toBeInTheDocument()
  })

  it('has data-slot', () => {
    render(<Component>Test</Component>)
    expect(screen.getByText('Test')).toHaveAttribute('data-slot', 'component')
  })

  it('applies variant classes', () => {
    render(<Component variant="secondary">Test</Component>)
    expect(screen.getByText('Test').className).toContain('bg-secondary')
  })

  it('merges custom className', () => {
    render(<Component className="custom">Test</Component>)
    expect(screen.getByText('Test').className).toContain('custom')
  })
})
```

## Story Pattern (CSF3)

```tsx
import type { Meta, StoryObj } from 'storybook'
import { Component } from './component'

const meta = {
  title: 'Category/Component',
  component: Component,
} satisfies Meta<typeof Component>

export default meta
type Story = StoryObj<typeof Component>

export const Default: Story = {}
export const Secondary: Story = { args: { variant: 'secondary' } }
```

## CSS Variables for New Theme Tokens

Add to `src/styles/globals.css` under `:root` and `.dark`:

```css
:root {
  --status-working: 210 100% 50%;  /* Neutral semantic default */
}
.dark {
  --status-working: 210 100% 60%;
}
```

Consumer repos override these with their own brand colors.

## Commands

```bash
bun run build      # Vite library build
bun run test       # Vitest
bun run lint       # Biome check
bun run lint:fix   # Biome auto-fix
bun run storybook  # Storybook dev server
```

## Release Process

- Automated via release-please
- Conventional commits determine version bumps
- Published to GitHub Packages (`@fx:registry=https://npm.pkg.github.com`)
