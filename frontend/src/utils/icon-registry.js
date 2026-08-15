import { SvgIcon } from '@mui/material'
import GlobeAltIcon from '@heroicons/react/24/outline/GlobeAltIcon'
import UsersIcon from '@heroicons/react/24/outline/UsersIcon'
import ServerIcon from '@heroicons/react/24/outline/ServerIcon'
import {
  AccessTime,
  AutoMode,
  History,
  Label,
  Webhook,
  AdminPanelSettings,
  Android,
  Apple,
  Apps,
  Assignment,
  BarChart,
  Business,
  CheckCircle,
  Cloud,
  Computer,
  Dashboard,
  Description,
  Devices,
  Dns,
  Domain,
  Email,
  FactCheck,
  FilePresent,
  Group,
  Groups,
  Home,
  Info,
  Key,
  Laptop,
  List,
  Lock,
  Mail,
  ManageAccounts,
  ManageSearch,
  Notifications,
  Person,
  PlayArrow,
  Policy,
  PrecisionManufacturing,
  Public,
  Science,
  Security,
  Settings,
  Share,
  Shield,
  ShieldMoon,
  Storage,
  Sync,
  Timeline,
  Window,
  Warning,
  VpnKey,
} from '@mui/icons-material'

export const iconRegistry = {
  AccessTime,
  AdminPanelSettings,
  Android,
  Apple,
  Apps,
  Assignment,
  BarChart,
  Business,
  CheckCircle,
  Cloud,
  Computer,
  Dashboard,
  Description,
  Devices,
  Dns,
  Domain,
  Email,
  FactCheck,
  FilePresent,
  Group,
  Groups,
  Home,
  Info,
  Key,
  Laptop,
  List,
  Lock,
  Mail,
  ManageAccounts,
  ManageSearch,
  Notifications,
  Person,
  PlayArrow,
  Policy,
  PrecisionManufacturing,
  Public,
  Science,
  Security,
  Settings,
  Share,
  Shield,
  ShieldMoon,
  Storage,
  AutoMode,
  History,
  Label,
  Sync,
  Timeline,
  Webhook,
  Window,
  Warning,
  VpnKey,
}

const heroIconAliases = {
  GlobeAltIcon,
  UsersIcon,
  ServerIcon,
}

export const getIconComponentByName = (iconName) => iconRegistry[iconName] ?? null

export const getIconByName = (iconName, props = {}) => {
  const Hero = heroIconAliases[iconName]
  if (Hero) {
    return (
      <SvgIcon {...props}>
        <Hero />
      </SvgIcon>
    )
  }

  const Icon = getIconComponentByName(iconName)
  return Icon ? <Icon {...props} /> : null
}
