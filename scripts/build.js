const fs = require('fs')
const path = require('path')
const { execSync } = require('child_process')
const stylus = require('stylus')
const autoprefixer = require('autoprefixer-stylus')

const pkgFile = path.join(__dirname, '../package.json')
const inputFile = path.join(__dirname, '../src/main.styl')
const outputFile = path.join(__dirname, '../dist/main.css')
const distDir = path.dirname(outputFile)

const readPackageJson = (filePath) => {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: package.json not found at ${filePath}. Run setup.sh first.`)
    process.exit(1)
  }

  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'))
  } catch (error) {
    console.error('Error: package.json could not be parsed.')
    console.error(error)
    process.exit(1)
  }
}

const writePackageJson = (filePath, data) => {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n')
}

const getRepositoryUrl = (repository) => {
  if (!repository) return ''
  if (typeof repository === 'string') return repository
  return repository.url || ''
}

const pkg = readPackageJson(pkgFile)

const isTruthy = (value) => ['1', 'true', 'yes'].includes(String(value).toLowerCase())
const autoCommitEnabled = !isTruthy(process.env.SKIP_GIT_COMMIT) && !isTruthy(process.env.CI)
const runGitHooks = isTruthy(process.env.RUN_GIT_HOOKS)

const tryAddFile = (filePath, { forceIfIgnored = false } = {}) => {
  const absolutePath = path.join(__dirname, '..', filePath)
  if (!fs.existsSync(absolutePath)) {
    console.log(`Skipping auto-commit: missing ${filePath}`)
    return false
  }

  try {
    execSync(`git add ${filePath}`, { stdio: 'inherit' })
    return true
  } catch (error) {
    if (forceIfIgnored) {
      try {
        execSync(`git add -f ${filePath}`, { stdio: 'inherit' })
        console.log(`Added ignored file: ${filePath}`)
        return true
      } catch (forceError) {
        const message = forceError && forceError.message ? forceError.message : String(forceError)
        console.log(`Skipping auto-commit: unable to add ${filePath} (${message})`)
        return false
      }
    }

    const message = error && error.message ? error.message : String(error)
    console.log(`Skipping auto-commit: unable to add ${filePath} (${message})`)
    return false
  }
}

const tryAutoCommit = (newVersion) => {
  if (!autoCommitEnabled) {
    return
  }

  try {
    execSync('git rev-parse --is-inside-work-tree', { stdio: 'ignore' })
  } catch {
    console.log('Skipping auto-commit: not a git repo')
    return
  }

  const staged = execSync('git diff --cached --name-only', { encoding: 'utf8' }).trim()
  if (staged) {
    console.log('Skipping auto-commit: staged changes present')
    return
  }

  const status = execSync('git status --porcelain', { encoding: 'utf8' }).trim()
  if (!status) {
    console.log('Skipping auto-commit: working tree clean')
    return
  }

  const allowedChangedFiles = new Set(['package.json', 'dist/main.css'])
  const otherChanges = status
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line.slice(2).trim())
    .map((filePath) => {
      const renameMatch = filePath.match(/.+ -> (.+)$/)
      return renameMatch ? renameMatch[1] : filePath
    })
    .filter((filePath) => !allowedChangedFiles.has(filePath))

  if (otherChanges.length) {
    console.log('Skipping auto-commit: other working tree changes present')
    return
  }

  tryAddFile('package.json')
  tryAddFile('dist/main.css', { forceIfIgnored: true })

  const stagedAfterAdd = execSync('git diff --cached --name-only', { encoding: 'utf8' }).trim()
  if (!stagedAfterAdd) {
    console.log('Skipping auto-commit: nothing staged after add')
    return
  }

  const message = `chore: verbump ${newVersion}`
  const noVerifyFlag = runGitHooks ? '' : ' --no-verify'
  try {
    execSync(`git commit -m "${message}"${noVerifyFlag}`, { stdio: 'inherit' })
  } catch (error) {
    const errorMessage = error && error.message ? error.message : String(error)
    console.log(`Skipping auto-commit: git commit failed (${errorMessage})`)
  }
}

// Bump version
const now = new Date()
const pad = (n) => n.toString().padStart(2, '0')
const version = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}.${pad(now.getHours())}.${pad(now.getMinutes())}`

// Initialize userStyle if missing
if (!pkg.userStyle) {
  pkg.userStyle = {
    namespace: `github.com/${pkg.author || 'unknown'}/${pkg.name}`,
    version: version
  }
} else {
  pkg.userStyle.version = version
}

writePackageJson(pkgFile, pkg)
console.log(`Bumped version to ${version}`)

// Create dist dir if not exists
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir, { recursive: true })
}

// Generate UserStyle header
const header = `/* ==UserStyle==
@name         ${pkg.name}
@version      ${version}
@namespace    ${pkg.userStyle.namespace}
@description  ${pkg.description || 'No description provided.'}
@author       ${pkg.author || 'Unknown'}
@github       ${getRepositoryUrl(pkg.repository)}
@homepageURL  ${pkg.homepage || ''}
@license      ${pkg.license || 'UNLICENSED'}
==/UserStyle== */

`

if (!fs.existsSync(inputFile)) {
  console.error(`Error: Source file not found: ${inputFile}`)
  process.exit(1)
}

const stylContent = fs.readFileSync(inputFile, 'utf8')

console.log('Building CSS...')

stylus(stylContent)
  .set('filename', inputFile)
  .set('compress', true)
  .use(autoprefixer())
  .render((err, css) => {
    if (err) {
      console.error('Error building CSS:', err)
      process.exit(1)
    }

    const finalCss = header + css
    fs.writeFileSync(outputFile, finalCss)
    console.log(`Build complete: ${outputFile}`)
    tryAutoCommit(version)
  })
