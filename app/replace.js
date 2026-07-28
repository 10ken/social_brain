const fs = require('fs');

const path = 'app/src/main/java/com/example/ui/screens/MainAppScreens.kt';
let content = fs.readFileSync(path, 'utf8');

const replacements = {
    'SocialMemoryColors.background': 'Slate900',
    'SocialMemoryColors.surfaceRaised': 'Slate850',
    'SocialMemoryColors.surface': 'Slate800',
    'SocialMemoryColors.textPrimary': 'Slate50',
    'SocialMemoryColors.textSecondary': 'Slate300',
    'SocialMemoryColors.textMuted': 'Slate400',
    'SocialMemoryColors.textOnAccent': 'Slate900',
    'SocialMemoryColors.borderSubtle': 'Slate700',
    'SocialMemoryColors.borderStrong': 'Slate700',
    'SocialMemoryColors.primaryStrong': 'Teal500',
    'SocialMemoryColors.primaryContainer': 'Teal100',
    'SocialMemoryColors.primary': 'Teal500',
    'SocialMemoryColors.warningContainer': 'Amber500.copy(alpha = 0.15f)',
    'SocialMemoryColors.warning': 'Amber500',
    'SocialMemoryColors.infoContainer': 'Sky500.copy(alpha = 0.15f)',
    'SocialMemoryColors.info': 'Sky500',
    'Color(0xFF7DD3FC)': 'Sky500', 
    'Color(0x4D0EA5E9)': 'Sky500.copy(alpha = 0.3f)',
    'SocialMemoryColors.textOnStrongAccent': 'Slate900',
    'Emerald500': 'Teal500',
    'Emerald400': 'Teal500',
    'Color.White': 'Slate50',
    'Color.Black': 'Slate900'
};

for (const [key, value] of Object.entries(replacements)) {
    content = content.split(key).join(value);
}

fs.writeFileSync(path, content, 'utf8');
console.log('Replaced all color tokens');
