"use client";
import {useEffect} from 'react';
import {mountInventoryMap,mountInventoryMorph} from './solutions-motion-runtime';
export function InventoryMapMotion(){useEffect(mountInventoryMap,[]);return null;}
export function InventoryMorphMotion(){useEffect(mountInventoryMorph,[]);return null;}
