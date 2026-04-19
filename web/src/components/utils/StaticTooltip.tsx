import React from 'react';
import { Paper, Text, Divider, Image } from '@mantine/core';
import { tokens } from '../../theme';
import { imagepath } from '../../store/imagepath';

export interface MythicItem {
  Name?: string;
  Label?: string;
  Quality?: number;
  MetaData?: Record<string, unknown>;
}

interface Props {
  item: MythicItem;
}

const HIDDEN_META = new Set(['description', 'label', 'type', 'ammo', 'serial', 'components', 'weapontint', 'container', 'durability', 'degrade']);

const StaticTooltip: React.FC<Props> = ({ item }) => {
  const imgSrc = item.Name ? `${imagepath}/${item.Name}.webp` : undefined;
  const description = item.MetaData?.description as string | undefined;

  return (
    <Paper
      style={{
        position: 'fixed',
        top: '50%',
        right: 24,
        transform: 'translateY(-50%)',
        border: `1px solid ${tokens.borderTeal}`,
        minWidth: 200,
        width: 220,
        zIndex: 99999,
        pointerEvents: 'none',
        boxShadow: `0 0 16px rgba(32,134,146,0.25)`,
      }}
      p="sm"
    >
      {imgSrc && (
        <Image
          src={imgSrc}
          width={48}
          height={48}
          fit="contain"
          mb={6}
          style={{ display: 'block', margin: '0 auto 6px' }}
        />
      )}
      <Text ff="'Orbitron', sans-serif" size="sm" c="white" fw={500} ta="center">
        {item.Label || item.Name}
      </Text>
      <Divider color={tokens.borderTeal} my={6} />
      {description && (
        <Text size="xs" ff="'Rajdhani', sans-serif" c={tokens.textSecondary} mb={4}>
          {description}
        </Text>
      )}
      {item.Quality !== undefined && (
        <Text size="xs" ff="'Rajdhani', sans-serif" c={tokens.textSecondary}>
          Quality: {item.Quality}%
        </Text>
      )}
      {item.MetaData &&
        Object.entries(item.MetaData)
          .filter(([key, val]) =>
            !HIDDEN_META.has(key) &&
            val !== null &&
            val !== undefined &&
            typeof val !== 'object'
          )
          .map(([key, val]) => {
            const label = key.replace(/([A-Z][a-z]+|[A-Z]+(?=[A-Z]|$))/g, ' $1').trim();
            return (
              <Text key={key} size="xs" ff="'Rajdhani', sans-serif" c={tokens.textSecondary}>
                {label}: {String(val)}
              </Text>
            );
          })}
    </Paper>
  );
};

export default StaticTooltip;
